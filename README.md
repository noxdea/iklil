# Iklil

Iklil (ρ Scorpii, from Arabic *iklīl*, “crown”) is a dependency-free Ruby
parser for RSS, Atom, JSON Feed, and OPML. It converts the formats into one
small immutable model and keeps diagnostics instead of dropping an entire feed
when one item is malformed.

## Features

- RSS 0.90/0.91/0.92/2.0 and RSS 1.0 (RDF)
- Atom 1.0
- JSON Feed 1.0 and 1.1
- OPML 1.0/2.0 import and deterministic export
- Relative URL resolution, date normalization, and common namespace extensions
- BOM/encoding handling, named-entity repair, control-character removal, and
  truncated XML recovery
- DTD and external entity removal before XML parsing
- Ruby standard library only; Ruby 3.2+

## Installation

```ruby
gem "iklil"
```

## Quick start

```ruby
require "iklil"

feed = Iklil.parse(File.binread("feed.xml"), base_url: "https://example.test/")
feed.format
feed.entries.first.title
feed.entries.first.published_at # a Time, or nil when absent/invalid
feed.diagnostics
```

All feed formats expose `Iklil::Feed`, `Iklil::Entry`, and
`Iklil::Enclosure`. `Entry#content_type` is `:html` or `:text`; Iklil does not
execute or sanitize HTML.

```ruby
subscriptions = Iklil.parse_opml(File.binread("subscriptions.opml"))
File.write("copy.opml", Iklil.render_opml(subscriptions, title: "Feeds"))
```

## Security

Iklil never fetches URLs. XML DTDs and entity declarations are removed before
REXML receives untrusted input, so feeds cannot make the parser read local or
remote files. Use a separate sanitizer before displaying HTML content.

## Development

```sh
bundle install
bundle exec rake
gem build --strict iklil.gemspec
```

## License

MIT. See [LICENSE.txt](LICENSE.txt).
