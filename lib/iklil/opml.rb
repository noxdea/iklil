# frozen_string_literal: true

module Iklil
  module OPML
    module_function

    def parse(bytes)
      text = Preprocess.call(bytes)
      document = REXML::Document.new(text)
      outlines = document.root && document.root.elements.to_a("body//outline")
      outlines ||= []
      outlines.filter_map do |outline|
        xml_url = XML.attribute(outline, "xmlUrl") || XML.attribute(outline, "xmlurl")
        next unless xml_url && !xml_url.empty?

        Subscription.new(
          title: XML.attribute(outline, "title") || XML.attribute(outline, "text"),
          xml_url: xml_url,
          html_url: XML.attribute(outline, "htmlUrl") || XML.attribute(outline, "htmlurl"),
          type: XML.attribute(outline, "type"), text: XML.attribute(outline, "text"),
          description: XML.attribute(outline, "description"), language: XML.attribute(outline, "language")
        )
      end
    rescue REXML::ParseException => error
      raise Error, "invalid OPML: #{error.message}"
    end

    def render(subscriptions, title:)
      groups = Hash.new { |hash, key| hash[key] = [] }
      Array(subscriptions).each do |subscription|
        groups[group_value(subscription)] << subscription
      end
      body = groups.map do |group, items|
        children = items.map { |item| render_outline(item) }.join
        if group.nil? || group.empty?
          children
        else
          "<outline text=\"#{escape(group)}\" title=\"#{escape(group)}\">#{children}</outline>"
        end
      end.join
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>#{escape(title)}</title></head>
          <body>#{body}</body>
        </opml>
      XML
    end

    def render_outline(subscription)
      values = {
        text: value(subscription, :text) || value(subscription, :title),
        title: value(subscription, :title) || value(subscription, :text),
        type: value(subscription, :type) || "rss",
        xmlUrl: value(subscription, :xml_url),
        htmlUrl: value(subscription, :html_url),
        description: value(subscription, :description),
        language: value(subscription, :language)
      }
      attributes = values.filter_map { |key, value| "#{key}=\"#{escape(value)}\"" if value && !value.to_s.empty? }.join(" ")
      "<outline #{attributes}/>"
    end

    def value(subscription, key)
      return subscription.public_send(key) if subscription.respond_to?(key)
      return subscription[key.to_s] || subscription[key] if subscription.is_a?(Hash)

      nil
    end

    def group_value(subscription)
      value(subscription, :group) || value(subscription, :category)
    end

    def escape(value)
      CGI.escapeHTML(value.to_s)
    end
  end
end
