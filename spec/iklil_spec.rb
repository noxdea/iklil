# frozen_string_literal: true

RSpec.describe Iklil do
  RSS = <<~XML
    <?xml version="1.0"?>
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel xml:base="https://example.test/news/">
        <title>News</title><link>/</link><description>Updates</description>
        <item><guid>one</guid><title>One</title><link>one.html</link>
          <pubDate>Tue, 02 Jan 2024 12:00:00 GMT</pubDate>
          <description>Summary &amp; more</description>
          <content:encoded>&lt;p&gt;Body&lt;/p&gt;</content:encoded>
          <category>ruby</category>
        </item>
      </channel>
    </rss>
  XML

  it "parses and normalizes RSS 2.0" do
    feed = described_class.parse(RSS, base_url: "https://example.test/")
    expect(feed.format).to eq(:rss2)
    expect(feed.site_url).to eq("https://example.test/")
    expect(feed.entries.first.url).to eq("https://example.test/news/one.html")
    expect(feed.entries.first.content_type).to eq(:html)
    expect(feed.entries.first.categories).to eq(["ruby"])
    expect(feed.entries.first.published_at).to be_a(Time)
  end

  it "parses Atom and JSON Feed" do
    atom = '<feed xmlns="http://www.w3.org/2005/Atom"><title>Atom</title><entry><id>a</id><title>A</title><updated>2024-01-01T00:00:00Z</updated><link href="/a"/></entry></feed>'
    json = { version: "https://jsonfeed.org/version/1.1", title: "JSON", items: [{ id: "j", title: "J", content_text: "text" }] }.to_json
    expect(described_class.parse(atom).entries.first.id).to eq("a")
    expect(described_class.parse(json).entries.first.content_type).to eq(:text)
  end

  it "repairs common broken XML without exposing entities" do
    broken = "\xEF\xBB\xBF<rss version='2.0'><channel><title>A&nbsp;B</title><item><title>cut".b
    feed = described_class.parse(broken)
    expect(feed.title).to eq("A B")
    expect(feed.entries.first.title).to eq("cut")

    xxe = '<!DOCTYPE rss [<!ENTITY secret SYSTEM "file:///etc/passwd">]><rss version="2.0"><channel><title>&secret;</title></channel></rss>'
    expect(described_class.parse(xxe).title).not_to include("root:")
  end

  it "round trips OPML subscriptions" do
    subscriptions = [Iklil::Subscription.new(title: "Ruby", xml_url: "https://example.test/feed.xml", html_url: "https://example.test", type: "rss", text: "Ruby", description: nil, language: "en")]
    result = described_class.parse_opml(described_class.render_opml(subscriptions, title: "Feeds"))
    expect(result.first.xml_url).to eq("https://example.test/feed.xml")
    expect(result.first.title).to eq("Ruby")
  end
end
