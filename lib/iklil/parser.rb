# frozen_string_literal: true

module Iklil
  class Parser
    class << self
      def parse(bytes, base_url:, encoding:)
        data = bytes.respond_to?(:read) ? bytes.read : bytes
        format = detect(data)
        return parse_json(data, base_url: base_url) if format == :json_feed

        text = Preprocess.call(data, encoding: encoding)
        document = xml_document(text)
        root = document.root
        return empty_feed(format, "feed has no root element") unless root

        case XML.local_name(root)
        when "rss"
          parse_rss(root, base_url: base_url)
        when "RDF", "rdf"
          parse_rss1(root, base_url: base_url)
        when "feed"
          parse_atom(root, base_url: base_url)
        else
          empty_feed(nil, "unsupported feed root #{root.name.inspect}")
        end
      rescue JSON::ParserError => error
        empty_feed(:json_feed, "invalid JSON Feed: #{error.message}")
      rescue REXML::ParseException => error
        empty_feed(format, "invalid XML: #{error.message}")
      rescue StandardError => error
        empty_feed(format, "could not parse feed: #{error.message}")
      end

      def detect(bytes)
        raw = (bytes.respond_to?(:read) ? bytes.read : bytes).to_s.b.sub(/\A(?:\xEF\xBB\xBF|\xFF\xFE|\xFE\xFF)/n, "")
        stripped = raw.lstrip
        if stripped.start_with?("{") || stripped.start_with?("[")
          begin
            value = JSON.parse(raw.force_encoding(Encoding::UTF_8))
            return :json_feed if value.is_a?(Hash) && value["version"].to_s.match?(%r{jsonfeed\.org/version/1})
          rescue JSON::ParserError
            return :json_feed if raw.match?(/"version"\s*:\s*"https?:\/\/jsonfeed\.org\/version\/1/i)
          end
        end

        root = stripped[/<\s*([A-Za-z_][\w:.-]*)/, 1].to_s.split(":").last
        case root
        when "rss"
          version = stripped[/<rss\b[^>]*\bversion\s*=\s*["']([^"']+)/i, 1].to_s
          version.start_with?("0.9") ? :rss09 : :rss2
        when "RDF", "rdf"
          :rss1
        when "feed"
          :atom
        else
          nil
        end
      end

      private

      def xml_document(text)
        REXML::Document.new(text)
      rescue REXML::ParseException
        recovered = Preprocess.close_open_elements(text)
        raise if recovered == text

        REXML::Document.new(recovered)
      end

      def parse_rss(root, base_url:)
        diagnostics = []
        channel = XML.child(root, "channel") || root
        feed_base = XML.base_url(base_url, channel)
        entries = XML.children(channel, "item").map.with_index do |item, index|
          rss_entry(item, base_url: XML.base_url(feed_base, item), diagnostics: diagnostics, path: "channel/item[#{index}]")
        end
        self_url = XML.children(channel).filter_map do |node|
          next unless XML.local_name(node) == "link" && XML.attribute(node, "rel") == "self"

          XML.resolve_url(XML.attribute(node, "href"), feed_base)
        end.first
        Feed.new(
          title: XML.path_text(channel, "title"),
          subtitle: XML.path_text(channel, "description"),
          url: self_url || feed_base,
          site_url: XML.resolve_url(XML.path_text(channel, "link"), feed_base),
          updated_at: date_value(XML.path_text(channel, "lastBuildDate"), diagnostics, "channel/lastBuildDate"),
          language: XML.path_text(channel, "language"),
          icon: XML.resolve_url(XML.path_text(channel, "image", "url"), feed_base),
          authors: rss_authors(channel),
          entries: entries,
          format: root.attributes["version"].to_s.start_with?("0.9") ? :rss09 : :rss2,
          diagnostics: diagnostics
        )
      end

      def parse_rss1(root, base_url:)
        diagnostics = []
        channel = XML.child(root, "channel") || root
        feed_base = XML.base_url(base_url, channel)
        entries = XML.children(root, "item").map.with_index do |item, index|
          rss_entry(item, base_url: XML.base_url(feed_base, item), diagnostics: diagnostics, path: "item[#{index}]")
        end
        Feed.new(
          title: XML.path_text(channel, "title"),
          subtitle: XML.path_text(channel, "description"),
          url: feed_base,
          site_url: XML.resolve_url(XML.path_text(channel, "link"), feed_base),
          updated_at: date_value(XML.path_text(channel, "date"), diagnostics, "channel/date"),
          language: XML.path_text(channel, "language"),
          icon: nil,
          authors: rss_authors(channel),
          entries: entries,
          format: :rss1,
          diagnostics: diagnostics
        )
      end

      def parse_atom(root, base_url:)
        diagnostics = []
        feed_base = XML.base_url(base_url, root)
        links = XML.children(root, "link")
        self_url = links.find { |link| XML.attribute(link, "rel").to_s == "self" }
        site_url = links.find { |link| [nil, "alternate"].include?(XML.attribute(link, "rel")) }
        entries = XML.children(root, "entry").map.with_index do |entry, index|
          atom_entry(entry, base_url: XML.base_url(feed_base, entry), diagnostics: diagnostics, path: "entry[#{index}]")
        end
        Feed.new(
          title: XML.deep_text(XML.child(root, "title")),
          subtitle: XML.deep_text(XML.child(root, "subtitle")),
          url: XML.resolve_url(XML.attribute(self_url, "href"), feed_base) || feed_base,
          site_url: XML.resolve_url(XML.attribute(site_url, "href"), feed_base),
          updated_at: date_value(XML.path_text(root, "updated"), diagnostics, "updated"),
          language: XML.attribute(root, "lang"),
          icon: XML.resolve_url(XML.path_text(root, "icon"), feed_base),
          authors: atom_authors(root),
          entries: entries,
          format: :atom,
          diagnostics: diagnostics
        )
      end

      def parse_json(bytes, base_url:)
        diagnostics = []
        raw = bytes.respond_to?(:read) ? bytes.read : bytes
        value = JSON.parse(raw.to_s.sub(/\A\xEF\xBB\xBF/, ""))
        unless value.is_a?(Hash) && value["version"].to_s.match?(%r{jsonfeed\.org/version/1})
          return empty_feed(:json_feed, "JSON document is not JSON Feed 1.x")
        end
        feed_base = base_url
        entries = Array(value["items"]).each_with_index.each_with_object([]) do |(item, index), result|
          if item.is_a?(Hash)
            result << json_entry(item, base_url: feed_base, diagnostics: diagnostics, path: "items[#{index}]")
          else
            diagnostics << Diagnostic.new(severity: :warning, message: "item is not an object", path: "items[#{index}]")
          end
        end
        Feed.new(
          title: value["title"], subtitle: value["description"], url: XML.resolve_url(value["feed_url"], feed_base) || feed_base,
          site_url: XML.resolve_url(value["home_page_url"], feed_base), updated_at: date_value(value["date_modified"], diagnostics, "date_modified"),
          language: value["language"], icon: value["icon"], authors: json_authors(value["author"] || value["authors"]),
          entries: entries, format: :json_feed, diagnostics: diagnostics
        )
      end

      def rss_entry(item, base_url:, diagnostics:, path:)
        link = XML.resolve_url(XML.path_text(item, "link"), base_url)
        guid = XML.path_text(item, "guid") || XML.attribute(item, "about")
        encoded = XML.child(item, "encoded") || XML.children(item).find { |node| node.name.to_s == "content:encoded" }
        summary = XML.path_text(item, "description")
        content = encoded ? XML.deep_text(encoded) : summary
        content_type = encoded ? :html : :text
        published = XML.path_text(item, "pubDate") || XML.path_text(item, "date")
        updated = XML.path_text(item, "lastBuildDate") || XML.path_text(item, "date")
        Entry.new(
          id: guid || link || stable_id(item, content), title: XML.path_text(item, "title"), url: link,
          summary: summary, content: content, content_type: content_type,
          published_at: date_value(published, diagnostics, "#{path}/pubDate"),
          updated_at: date_value(updated, diagnostics, "#{path}/lastBuildDate"), authors: rss_authors(item),
          categories: XML.children(item, "category").filter_map { |node| XML.text(node) },
          enclosures: rss_enclosures(item, base_url),
          extensions: XML.extension_values(item, known: %w[title link guid description pubDate date lastBuildDate author category enclosure])
        )
      end

      def atom_entry(entry, base_url:, diagnostics:, path:)
        links = XML.children(entry, "link")
        link = links.find { |node| [nil, "alternate"].include?(XML.attribute(node, "rel")) }
        content_node = XML.child(entry, "content")
        raw_content_type = XML.attribute(content_node, "type").to_s.downcase
        content = content_node && (content_node.has_elements? ? XML.inner_xml(content_node) : XML.deep_text(content_node))
        content_type = if %w[html xhtml text/html application/xhtml+xml].include?(raw_content_type) || (raw_content_type.empty? && content_node&.has_elements?)
                         :html
                       else
                         :text
                       end
        summary = XML.deep_text(XML.child(entry, "summary"))
        Entry.new(
          id: XML.path_text(entry, "id") || XML.resolve_url(XML.attribute(link, "href"), base_url) || stable_id(entry, content),
          title: XML.deep_text(XML.child(entry, "title")), url: XML.resolve_url(XML.attribute(link, "href"), base_url),
          summary: summary, content: content || summary, content_type: content_type,
          published_at: date_value(XML.path_text(entry, "published"), diagnostics, "#{path}/published"),
          updated_at: date_value(XML.path_text(entry, "updated"), diagnostics, "#{path}/updated"),
          authors: atom_authors(entry), categories: XML.children(entry, "category").filter_map { |node| XML.attribute(node, "term") || XML.text(node) },
          enclosures: links.filter_map do |node|
            next unless XML.attribute(node, "rel") == "enclosure"
            Enclosure.new(url: XML.resolve_url(XML.attribute(node, "href"), base_url), type: XML.attribute(node, "type"), length: integer(XML.attribute(node, "length")), duration: nil, title: XML.attribute(node, "title"))
          end,
          extensions: XML.extension_values(entry, known: %w[id title link summary content published updated author category])
        )
      end

      def json_entry(item, base_url:, diagnostics:, path:)
        html = item["content_html"]
        text = item["content_text"]
        content = html || text || item["summary"]
        content_type = html ? :html : :text
        attachments = Array(item["attachments"]).filter_map do |attachment|
          next unless attachment.is_a?(Hash) && attachment["url"]
          Enclosure.new(url: XML.resolve_url(attachment["url"].to_s, base_url), type: attachment["mime_type"], length: integer(attachment["size_in_bytes"]), duration: attachment["duration_in_seconds"], title: attachment["title"])
        end
        Entry.new(
          id: item["id"] || XML.resolve_url(item["url"].to_s, base_url) || stable_id(item, content),
          title: item["title"], url: XML.resolve_url(item["url"].to_s, base_url), summary: item["summary"], content: content,
          content_type: content_type, published_at: date_value(item["date_published"], diagnostics, "#{path}/date_published"),
          updated_at: date_value(item["date_modified"], diagnostics, "#{path}/date_modified"), authors: json_authors(item["author"] || item["authors"]),
          categories: Array(item["tags"]), enclosures: attachments,
          extensions: item.reject { |key, _| %w[id title url external_url content_html content_text summary date_published date_modified author authors tags attachments].include?(key) }
        )
      end

      def rss_authors(element)
        %w[author creator].filter_map { |name| XML.children(element, name).filter_map { |node| XML.text(node) } }.flatten.uniq
      end

      def atom_authors(element)
        XML.children(element, "author").filter_map do |author|
          XML.deep_text(XML.child(author, "name")) || XML.text(author)
        end.uniq
      end

      def json_authors(author)
        Array(author).filter_map { |value| value.is_a?(Hash) ? (value["name"] || value["url"]) : value }.map(&:to_s).reject(&:empty?).uniq
      end

      def rss_enclosures(item, base_url)
        XML.children(item).filter_map do |node|
          next unless %w[enclosure content].include?(XML.local_name(node)) && (node.name == "enclosure" || XML.attribute(node, "url"))
          Enclosure.new(url: XML.resolve_url(XML.attribute(node, "url"), base_url), type: XML.attribute(node, "type"), length: integer(XML.attribute(node, "length") || XML.attribute(node, "fileSize")), duration: XML.attribute(node, "duration"), title: XML.attribute(node, "title"))
        end
      end

      def date_value(value, diagnostics, path)
        return nil if value.nil? || value.to_s.strip.empty?

        DateTime.parse(value.to_s).to_time
      rescue ArgumentError, TypeError
        diagnostics << Diagnostic.new(severity: :warning, message: "invalid date #{value.inspect}", path: path)
        nil
      end

      def integer(value)
        Integer(value, 10) if value && value.to_s.match?(/\A\d+\z/)
      rescue ArgumentError
        nil
      end

      def stable_id(value, content)
        source = value.respond_to?(:expanded_name) ? XML.inner_xml(value) : value.to_s
        Digest::SHA256.hexdigest([source, content].join("\u0000"))
      end

      def empty_feed(format, message)
        Feed.new(title: nil, subtitle: nil, url: nil, site_url: nil, updated_at: nil, language: nil, icon: nil, authors: [], entries: [], format: format, diagnostics: [Diagnostic.new(severity: :error, message: message, path: nil)])
      end
    end
  end
end
