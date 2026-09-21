# frozen_string_literal: true

module Iklil
  module XML
    module_function

    def local_name(element)
      element.name.to_s.split(":").last
    end

    def child(element, name)
      return nil unless element

      element.elements.find { |item| local_name(item) == name }
    end

    def children(element, name = nil)
      return [] unless element

      elements = element.elements.to_a
      name ? elements.select { |item| local_name(item) == name } : elements
    end

    def text(element)
      return nil unless element

      value = element.texts.map(&:value).join
      value = value.strip
      value.empty? ? nil : value
    end

    def attribute(element, name)
      return nil unless element

      element.attributes.each_attribute do |attribute|
        return attribute.value if attribute.expanded_name == name || attribute.name == name || attribute.name.split(":").last == name
      end
      nil
    end

    def path_text(element, *names)
      names.reduce(element) { |current, name| child(current, name) }.then { |node| text(node) }
    end

    def base_url(base, element)
      relative = attribute(element, "base")
      return base unless relative && !relative.empty?
      return relative unless base && !base.empty?

      URI.join(base, relative).to_s
    rescue URI::InvalidURIError
      relative
    end

    def resolve_url(value, base)
      return nil if value.nil? || value.empty?
      return value unless base && !base.empty?

      URI.join(base, value).to_s
    rescue URI::InvalidURIError
      value
    end

    def tree_text(element)
      return "" unless element

      element.children.map { |node| node.respond_to?(:value) ? node.value.to_s : tree_text(node) }.join
    end

    def deep_text(element)
      return nil unless element

      value = tree_text(element).strip
      value.empty? ? nil : value
    end

    def inner_xml(element)
      return "" unless element

      element.children.map do |node|
        if node.respond_to?(:value)
          CGI.escapeHTML(node.value.to_s)
        else
          attributes = node.attributes.each_attribute.map { |attribute| "#{attribute.expanded_name}=\"#{CGI.escapeHTML(attribute.value.to_s)}\"" }
          opening = attributes.empty? ? "<#{node.name}>" : "<#{node.name} #{attributes.join(" ")}>"
          "#{opening}#{inner_xml(node)}</#{node.name}>"
        end
      end.join
    end

    def extension_values(element, known: [])
      return {} unless element

      element.elements.each_with_object({}) do |node, result|
        local = local_name(node)
        next if known.include?(local)

        key = node.expanded_name.to_s
        value = if node.has_elements?
                  extension_values(node)
                else
                  text(node) || ""
                end
        result[key] = result.key?(key) ? Array(result[key]) + [value] : value
      end
    end
  end
end
