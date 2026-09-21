# frozen_string_literal: true

module Iklil
  Diagnostic = Data.define(:severity, :message, :path) do
    def warning?
      severity == :warning
    end
  end

  Enclosure = Data.define(:url, :type, :length, :duration, :title)

  Entry = Data.define(
    :id, :title, :url, :summary, :content, :content_type,
    :published_at, :updated_at, :authors, :categories, :enclosures, :extensions
  ) do
    def html?
      content_type == :html
    end

    def text?
      content_type == :text
    end
  end

  Feed = Data.define(
    :title, :subtitle, :url, :site_url, :updated_at, :language, :icon,
    :authors, :entries, :format, :diagnostics
  ) do
    def valid?
      !diagnostics.any? { |diagnostic| diagnostic.severity == :error }
    end
  end

  Subscription = Data.define(
    :title, :xml_url, :html_url, :type, :text, :description, :language
  )
end
