# frozen_string_literal: true

module Iklil
  # Converts untrusted XML bytes into a UTF-8, non-executable XML document.
  # DTDs are removed before REXML sees the input; REXML must never resolve
  # external entities from a feed.
  module Preprocess
    module_function

    XML_DECLARATION = /\A\s*<\?xml\s+[^>]*encoding\s*=\s*["']([^"']+)["']/im
    VALID_ENTITIES = %w[amp apos gt lt quot].freeze
    NAMED_ENTITIES = {
      "nbsp" => 160, "copy" => 169, "reg" => 174, "trade" => 8482,
      "hellip" => 8230, "mdash" => 8212, "ndash" => 8211, "laquo" => 171,
      "raquo" => 187, "ldquo" => 8220, "rdquo" => 8221, "lsquo" => 8216,
      "rsquo" => 8217, "bull" => 8226, "rarr" => 8594, "times" => 215,
      "euro" => 8364, "yen" => 165, "pound" => 163
    }.freeze

    def call(bytes, encoding: :auto)
      raw = (bytes.respond_to?(:read) ? bytes.read : bytes).to_s.b.dup
      source_encoding = encoding == :auto ? sniff_encoding(raw) : encoding
      raw = strip_bom(raw)
      text = decode(raw, source_encoding)
      text = strip_dtd(text)
      text = repair_entities(text)
      text = strip_control_chars(text)
      text.force_encoding(Encoding::UTF_8)
      text
    end

    def strip_bom(bytes)
      bytes.sub(/\A(?:\xEF\xBB\xBF|\xFF\xFE|\xFE\xFF)/n, "")
    end

    def sniff_encoding(bytes)
      return Encoding::UTF_16LE if bytes.start_with?("\xFF\xFE".b)
      return Encoding::UTF_16BE if bytes.start_with?("\xFE\xFF".b)

      match = bytes.byteslice(0, 512).to_s.force_encoding(Encoding::ASCII_8BIT).match(XML_DECLARATION)
      return Encoding::UTF_8 unless match

      Encoding.find(match[1].strip.tr("_", "-"))
    rescue ArgumentError
      Encoding::UTF_8
    end

    def decode(bytes, encoding)
      source = encoding.is_a?(Encoding) ? encoding : Encoding.find(encoding.to_s)
      bytes.dup.force_encoding(source).encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
    rescue Encoding::ConverterNotFoundError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      bytes.dup.force_encoding(Encoding::UTF_8).scrub("�")
    end

    def strip_dtd(text)
      # Handles both a simple declaration and an internal subset containing >.
      without_doctype = text.gsub(/<!DOCTYPE\b[^\[]*(?:\[[\s\S]*?\]\s*)?>/i, "")
      without_doctype.gsub(/<!ENTITY\b[^>]*>/i, "")
    end

    def repair_entities(text)
      text.gsub(/&(#(?:x[0-9a-f]+|[0-9]+)|[A-Za-z][A-Za-z0-9]+);/i) do |entity|
        value = Regexp.last_match(1)
        if valid_numeric_entity?(value) || VALID_ENTITIES.include?(value)
          entity
        elsif NAMED_ENTITIES.key?(value.downcase)
          "&#" + NAMED_ENTITIES.fetch(value.downcase).to_s + ";"
        else
          "&amp;#{value};"
        end
      end
    end

    def strip_control_chars(text)
      text.delete("\x00-\x08\x0B\x0C\x0E-\x1F\x7F")
    end

    def valid_numeric_entity?(value)
      return false unless value.start_with?("#")

      number = value.start_with?("#x", "#X") ? value[2..].to_i(16) : value[1..].to_i(10)
      number == 9 || number == 10 || number == 13 || (number >= 0x20 && number <= 0xD7FF) ||
        (number >= 0xE000 && number <= 0xFFFD) || (number >= 0x10000 && number <= 0x10FFFF)
    end

    # A small recovery pass for the common case of a feed truncated while it
    # was being downloaded. It is only used after REXML rejects the document.
    def close_open_elements(text)
      stack = []
      text.scan(/<\s*(\/?)\s*([A-Za-z_][\w:.-]*)(?:\s[^<>]*?)?(\/?)\s*>/) do |closing, name, self_closing|
        if closing == "/"
          index = stack.rindex(name)
          stack.slice!(index..-1) if index
        elsif self_closing != "/" && !%w[br hr img link meta].include?(name.downcase)
          stack << name
        end
      end
      stack.reverse.reduce(text) { |value, name| "#{value}</#{name}>" }
    end
  end
end
