# frozen_string_literal: true

require_relative "lib/iklil/version"

Gem::Specification.new do |spec|
  spec.name = "iklil"
  spec.version = Iklil::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]
  spec.summary = "Tolerant RSS, Atom, JSON Feed, and OPML parser"
  spec.description = "A dependency-free Ruby parser that normalizes RSS, Atom, JSON Feed, and OPML data while safely handling malformed input."
  spec.homepage = "https://github.com/noxdea/iklil"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "docs/**/*.md", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
