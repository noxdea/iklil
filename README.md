<h1 align="center">Iklil</h1>

<p align="center"><strong>Normalize RSS, Atom, and JSON Feed in Ruby; import and export OPML.</strong></p>

<p align="center">
  <a href="https://rubygems.org/gems/iklil"><img src="https://img.shields.io/gem/v/iklil" alt="Gem version"></a>
  <a href="https://github.com/noxdea/iklil/actions/workflows/main.yml"><img src="https://github.com/noxdea/iklil/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/Ruby-3.2%2B-cc342d" alt="Ruby 3.2 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#opml">OPML</a> ·
  <a href="#safety-and-scope">Safety and scope</a>
</p>

---

Iklil is a dependency-free Ruby feed parser for readers, importers, and
archivers. It maps supported formats to immutable `Feed`, `Entry`, and
`Enclosure` values; malformed fields become diagnostics instead of silently
discarding an entire feed. The name comes from ρ Scorpii and the Arabic
*iklīl*, “crown.”

## Features

- RSS 0.90, 0.91, 0.92, 1.0 (RDF), and 2.0; Atom 1.0; JSON Feed 1.0 and 1.1
- OPML 1.0/2.0 import and deterministic export
- Relative URL resolution, date normalization, and common namespace fields
- Encoding/BOM handling, entity repair, and recovery from truncated XML
- Diagnostics for invalid fields; Ruby standard library only

## Installation

Add `gem "iklil"` to your Gemfile and run `bundle install`, or install directly:

```sh
gem install iklil
```

Requires Ruby 3.2 or newer.

## Quick start

```ruby
require "iklil"

xml = '<rss version="2.0"><channel><title>Notes</title>' \
      '<item><title>Hello</title><link>/hello</link></item>' \
      '</channel></rss>'

feed = Iklil.parse(xml, base_url: "https://example.com/")
puts feed.title                         # => Notes
puts feed.entries.first.url             # => https://example.com/hello
puts feed.diagnostics.map(&:message)    # warnings, if any
```

The same `Iklil.parse` call accepts RSS, Atom, and JSON Feed bytes. Pass the
source URL as `base_url:` so relative links resolve correctly. `Entry#content_type`
is `:html` or `:text`; absent or invalid dates remain `nil`.

See [field normalization](docs/normalization.md) for format-by-format mappings.

## OPML

```ruby
subscriptions = Iklil.parse_opml(File.binread("subscriptions.opml"))
File.write("copy.opml", Iklil.render_opml(subscriptions, title: "My feeds"))
```

## Safety and scope

Iklil parses bytes; it never fetches URLs. It removes XML DTDs and entity
declarations before parsing, but it does **not** sanitize HTML from a feed.
Sanitize HTML before rendering it in an application. See the
[parsing decisions](docs/adr/002-tolerant-safe-parsing.md).

## Development

```sh
bundle install
bundle exec rake
gem build --strict iklil.gemspec
```

## License

[MIT](LICENSE.txt)
