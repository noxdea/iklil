# Feed normalization

Iklil maps each supported input to the same `Feed`, `Entry`, and `Enclosure`
models. Missing values remain `nil`; malformed values add a warning to
`Feed#diagnostics` rather than aborting the complete feed.

| Common field | RSS 2.0 / RSS 0.9x | RSS 1.0 | Atom 1.0 | JSON Feed |
| --- | --- | --- | --- | --- |
| `id` | `guid`, then `link`, then SHA-256 | `rdf:about`, then `link`, then SHA-256 | `id`, then link, then SHA-256 | `id`, then `url`, then SHA-256 |
| `title` | `title` | `title` | `title` | `title` |
| `published_at` | `pubDate`, `date` | `dc:date`, `date` | `published` | `date_published` |
| `updated_at` | `lastBuildDate` | `dc:date` | `updated` | `date_modified` |
| `summary` | `description` | `description` | `summary` | `summary` |
| `content` | `content:encoded`, then `description` | `content:encoded`, then `description` | `content`, then `summary` | `content_html`, then `content_text`, then `summary` |
| `content_type` | `:html` for `content:encoded`, otherwise `:text` | same | `type="html"`/`xhtml` => `:html` | `content_html` => `:html`, otherwise `:text` |
| `url` | `link` | `link` | alternate `link` | `url` |

Relative URLs are resolved against the caller's `base_url` and inherited
`xml:base` values. Namespace fields not needed for the common model are kept
in `Entry#extensions` under their original qualified name.
