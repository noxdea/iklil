# frozen_string_literal: true

require "cgi"
require "date"
require "digest"
require "json"
require "rexml/document"
require "time"
require "uri"

require_relative "iklil/version"
require_relative "iklil/models"
require_relative "iklil/preprocess"
require_relative "iklil/xml"
require_relative "iklil/parser"
require_relative "iklil/opml"

module Iklil
  class Error < StandardError; end

  module_function

  def parse(bytes, base_url: nil, encoding: :auto)
    Parser.parse(bytes, base_url: base_url, encoding: encoding)
  end

  def detect(bytes)
    Parser.detect(bytes)
  end

  def parse_opml(bytes)
    OPML.parse(bytes)
  end

  def render_opml(subscriptions, title: "Iklil subscriptions")
    OPML.render(subscriptions, title: title)
  end
end
