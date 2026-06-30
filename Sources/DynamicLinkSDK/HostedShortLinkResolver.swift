import Foundation
import SwiftUI

/// Parses Tecocraft-style short link HTML (`/s/{slug}`) where the server returns 200 + JS/meta redirect (no HTTP 302).
public enum HostedShortLinkHTMLParser {
    /// Best-effort extraction of the outbound URL from a landing page.
    public static func firstRedirectURL(inHTML html: String) -> URL? {
        let patterns: [String] = [
            #"window\.location\.replace\(\s*"([^"]+)""#,
            #"window\.location\.replace\(\s*'([^']+)'"#,
            #"var\s+dest\s*=\s*"([^"]+)""#,
            #"<meta[^>]*http-equiv=["']refresh["'][^>]*content=["'][^"']*url\s*=\s*([^"]+)""#,
            #"window\.location\.href\s*=\s*"([^"]+)""#,
            #"<link[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']"#,
        ]
        for pattern in patterns {
            if let url = firstMatch(in: html, pattern: pattern) {
                return url
            }
        }
        return nil
    }
//
    private static func firstMatch(in html: String, pattern: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex ..< html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
            match.numberOfRanges >= 2,
            let r = Range(match.range(at: 1), in: html)
        else { return nil }
        let raw = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        let decoded = raw.removingPercentEncoding ?? raw
        guard let url = URL(string: decoded) else { return nil }
        guard url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }
}
//
