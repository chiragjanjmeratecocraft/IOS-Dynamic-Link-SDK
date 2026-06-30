import Foundation
import Testing

@testable import DynamicLinkSDK

@Test func extractShortCode_fromQuery() {
    let url = "https://links.example.com/path?short_code=abc123&x=1"
    #expect(DynamicLinkClient.extractShortCode(from: url) == "abc123")
}

@Test func extractShortCode_percentEncoded() {
    let url = "myapp://open?short_code=hello%2Bworld"
    #expect(DynamicLinkClient.extractShortCode(from: url) == "hello+world")
}

@Test func extractShortCode_missing() {
    #expect(DynamicLinkClient.extractShortCode(from: "myapp://open?foo=1") == nil)
    #expect(DynamicLinkClient.extractShortCode(from: "nope") == nil)
}

@Test func defaultBaseURL_matchesRNConstants() {
    #expect(defaultDynamicLinkBaseURL.absoluteString == "https://backend-dynamiclink.tecocraft.us/api/links")
}

@Test func hostedShortLink_detectsPath() {
    let api = URL(string: "https://backend-dynamiclink.tecocraft.us/api/links")!
    let u = URL(string: "https://backend-dynamiclink.tecocraft.us/s/9Xa80Hh")!
    #expect(DynamicLinkClient.isHostedShortLinkPage(u, apiBaseURL: api))
    #expect(DynamicLinkClient.isHostedShortLinkPage(URL(string: "https://other.com/s/x")!, apiBaseURL: api) == false)
}

@Test func decodePendingRedirect_readsShortCodeOnly() throws {
    let json = """
    {
      "statusCode": 200,
      "success": true,
      "message": "ok",
      "data": {
        "short_code": "abc123"
      }
    }
    """
    let data = try #require(json.data(using: .utf8))
    let envelope = try JSONDecoder().decode(DynamicLinkAPIEnvelope<PendingRedirectData>.self, from: data)
    #expect(envelope.data?.shortCode == "abc123")
}

@Test func decodePendingRedirect_emptyData() throws {
    let json = """
    { "statusCode": 200, "success": true, "data": null }
    """
    let data = try #require(json.data(using: .utf8))
    let envelope = try JSONDecoder().decode(DynamicLinkAPIEnvelope<PendingRedirectData>.self, from: data)
    #expect(envelope.data == nil)
}

@Test func extractShortCode_pathFallback_onAllowedHost() {
    let hosts: Set<String> = ["backend-dynamiclink.tecocraft.us"]
  #expect(
        DynamicLinkClient.extractShortCodeWithPathFallback(
            from: "https://backend-dynamiclink.tecocraft.us/3SxE2G",
            allowedHosts: hosts
        ) == "3SxE2G"
    )
    #expect(
        DynamicLinkClient.extractShortCodeWithPathFallback(
            from: "https://other.example.com/3SxE2G",
            allowedHosts: hosts
        ) == nil
    )
}

@Test func decodeResponse_readsCustomJSONFromDataField() throws {
    let json = """
    {
      "name": "Test Link",
      "description": "Desc",
      "short_code": "abc123",
      "custom_domain": null,
      "projectId": "proj-1",
      "android_scheme": "song",
      "ios_scheme": "song",
      "desktop_link": null,
      "data": {
        "screen": "library",
        "song_id": 2,
        "extra": { "source": "deeplink" }
      },
      "project": {
        "id": "p1",
        "name": "Demo",
        "description": "",
        "on_playstore": true,
        "on_appstore": true,
        "android_package_name": "com.example",
        "ios_bundle_id": "com.example",
        "default_url": "https://example.com",
        "android_fallback_url": "https://example.com",
        "ios_fallback_url": "https://example.com",
        "android_host": null,
        "ios_host": null
      }
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(DynamicLinkResponse.self, from: data)
    #expect(response.customData?["screen"] == .string("library"))
    #expect(response.params?["screen"] == "library")
    #expect(response.payloadJSON?.contains("\"song_id\"") == true)
    #expect(response.payloadJSON?.contains("\"extra\"") == true)
}

@Test func hostedShortLinkHTML_extractsSnapchatFromSample() {
    let html = #"""
    <meta http-equiv="refresh" content="0;url=https://www.snapchat.com/p/2508f100/story" />
    <script>var dest = "https://www.snapchat.com/p/2508f100/story";window.location.replace(dest);</script>
    """#
    let out = HostedShortLinkHTMLParser.firstRedirectURL(inHTML: html)
    #expect(out?.host == "www.snapchat.com")
}
