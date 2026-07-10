# IOS Dynamic Link SDK

**Repository:** [github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK](https://github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK)

A native **Swift / iOS** SDK for **Deep Links**, **Universal Links**, **Deferred Deep Links**, and **in-app link sharing** using the Tecocraft Dynamic Link backend.

Configure your project `clientId`, wrap your app root with `SmartLinkingRoot`, and navigate using JSON you define in the **Dynamic Link Tool** — no third-party link services required.

---

## Features

- **iOS 15+** via Swift Package Manager
- **Smart linking** — handles links while the app is installed and on first launch after install
- **In-app share links** — generate a dynamic link from your app and open the iOS share sheet
- Resolves links with `?short_code=` via `GET /api/links/code/{code}`
- Supports HTTPS path-based short codes on your backend domain
- Parses hosted short-link pages (`https://…/s/{slug}`) for HTML redirects
- **SwiftUI** helper (`SmartLinkingRoot`) or **UIKit** manual wiring
- Typed models with full JSON payload support (`customData`, `payloadJSON`)
- Per-project **`clientId`** header on all backend API requests

---

## Installation

### Swift Package Manager (Git)

In Xcode: **File → Add Package Dependencies…** and enter your repository URL:

```text
https://github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK.git
```

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK.git", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["DynamicLinkSDK"])
]
```

### Local path (development)

**File → Add Package Dependencies… → Add Local…** and select this repository folder.

---

## Quick Start (60 seconds)

### 1. Register a URL scheme

Add to your app target’s `Info.plist` (scheme must match the Dynamic Link Tool):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

### 2. Configure `clientId`

Every project in the Dynamic Link Tool has a unique **`clientId`**. The SDK sends it as an HTTP header on all API requests (`GET /code`, `POST /pending-redirect`, `POST /public-link`).

```swift
let configuration = DynamicLinkConfiguration(
    clientId: "YOUR_CLIENT_ID_FROM_DYNAMIC_LINK_TOOL"
)
```

### 3. Wire the SDK (SwiftUI)

```swift
import SwiftUI
import DynamicLinkSDK

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SmartLinkingRoot(
                configuration: DynamicLinkConfiguration(clientId: "YOUR_CLIENT_ID"),
                options: SmartLinkingOptions(
                    onUrl: { url in print("URL:", url) },
                    onSuccess: { data in route(from: data) },
                    onError: { error in print("Error:", error.localizedDescription) }
                )
            ) {
                ContentView()
            }
        }
    }

    func route(from data: DynamicLinkResponse) {
        let payload = data.customData ?? [:]
        let screen = payload["screen"]?.scalarString?.lowercased()
        // Navigate based on screen and other JSON fields
    }
}
```

### 4. Test on Simulator

```sh
xcrun simctl openurl booted "myapp://open?short_code=YOUR_CODE"
```

---

## How it works

The SDK covers two flows: **opening links** (deep linking) and **creating links** (in-app share).

### Opening a link (deep linking)

`SmartLinkingRoot` runs three flows automatically:

| Flow | When | What the SDK does |
|------|------|-------------------|
| **Deferred deep link** | First app launch after install | Calls `POST /api/links/pending-redirect` once |
| **Custom scheme link** | User opens `myapp://...` | Extracts `short_code` → fetches link JSON |
| **Universal Link** | User opens `https://your-domain/...` | Same pipeline via system Universal Link handler |

All three call your **`onSuccess`** handler with the same `DynamicLinkResponse`. You use one navigation function for every case.

```
User taps link
      ↓
App opens (or installs then opens)
      ↓
SDK calls backend with clientId header
      ↓
onSuccess(data) — JSON in data.customData
      ↓
Your code navigates to the target screen
```

### Creating a link from your app (share)

When the user taps **Share** in your app, the SDK calls `POST /api/links/public-link` with your `clientId` header, receives a `short_code`, builds a share URL, and you present the iOS share sheet.

```
User taps Share in your app
      ↓
SDK POST /public-link (clientId header + JSON payload)
      ↓
Backend returns short_code
      ↓
Share URL: https://backend-dynamiclink.tecocraft.us/{shortCode}
      ↓
iOS share sheet opens
      ↓
Recipient taps link → same deep link flow as above
```

---

## Usage

### SwiftUI — `SmartLinkingRoot` (recommended)

```swift
SmartLinkingRoot(
    configuration: DynamicLinkConfiguration(clientId: "YOUR_CLIENT_ID"),
    options: SmartLinkingOptions(
        onUrl: { url in /* raw URL string */ },
        onSuccess: { data in /* resolved link + JSON payload */ },
        onError: { error in /* network or decode errors */ },
        onResolvedDestination: { url in /* hosted /s/… page resolved to external URL */ }
    )
) {
    ContentView()
}
```

Test manually from any child view:

```swift
@Environment(\.smartLinkingCoordinator) private var coordinator

await coordinator?.handleIncomingURLString("myapp://open?short_code=abc")
```

### SwiftUI — view modifier

If you already own a coordinator:

```swift
@StateObject private var coordinator = SmartLinkingCoordinator()

ContentView()
    .smartLinking(coordinator, options: SmartLinkingOptions(onSuccess: { data in
        // navigate
    }))
```

### UIKit

```swift
import DynamicLinkSDK

final class AppDelegate: NSObject, UIApplicationDelegate {
    let coordinator = SmartLinkingCoordinator(
        client: DynamicLinkClient(
            configuration: DynamicLinkConfiguration(clientId: "YOUR_CLIENT_ID")
        )
    )

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            await coordinator.start(options: SmartLinkingOptions(
                onSuccess: { data in /* navigate */ }
            ))
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Task { await coordinator.handleOpenURL(url) }
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        Task { await coordinator.handleContinueUserActivity(userActivity) }
        return true
    }
}
```

### Share a link from your app

Generate a dynamic link at runtime and open the iOS share sheet:

```swift
let client = DynamicLinkClient(
    configuration: DynamicLinkConfiguration(clientId: "YOUR_CLIENT_ID")
)

let result = try await client.createPublicLink(
    PublicLinkCreateRequest(
        title: "Product name",
        description: "Product description",
        iosScheme: "myapp",
        data: [
            "screen_name": .string("product"),
            "productId": .string("SKU-10026"),
        ]
    )
)

// result.shortCode  → "3SxE2G"
// result.shareURL   → https://backend-dynamiclink.tecocraft.us/3SxE2G
```

Present the share sheet with `DynamicLinkShareSheet`:

```swift
@State private var showShareSheet = false
@State private var shareURL: URL?

.sheet(isPresented: $showShareSheet) {
    if let shareURL {
        DynamicLinkShareSheet(items: [shareURL, "Check this out!"])
    }
}
```

The project is identified by the **`clientId` header** — do not send `projectId` in the request body.

Equivalent API call:

```sh
curl --location 'https://backend-dynamiclink.tecocraft.us/api/links/public-link' \
--header 'Content-Type: application/json' \
--header 'clientId: YOUR_CLIENT_ID' \
--data '{
    "title": "Product name",
    "description": "Product description",
    "ios_scheme": "myapp",
    "android_scheme": "myapp",
    "data": {
        "screen_name": "product",
        "productId": "SKU-10026"
    }
}'
```

---

## JSON payload and navigation

When you create a link in the **Dynamic Link Tool**, add **JSON Data** to control in-app navigation.

Example — open a specific user profile:

```json
{
  "screen": "user_detail",
  "user_id": "u-101"
}
```

In `onSuccess`:

```swift
onSuccess: { data in
    if let json = data.payloadJSON {
        print(json)  // full pretty-printed JSON
    }

    let payload = data.customData ?? [:]
    let screen = payload["screen"]?.scalarString?.lowercased()
    let userId = payload["user_id"]?.scalarString

    switch screen {
    case "user_detail":
        if let userId {
            // push UserDetailView(userId: userId)
        }
    case "all_users":
        // push AllUsersView()
    default:
        break
    }
}
```

| Field on `DynamicLinkResponse` | Description |
|-------------------------------|-------------|
| `customData` | Full JSON map from the link (`data` field in API) |
| `payloadJSON` | Pretty-printed JSON string for logging |
| `params` | Flat string map (simple key/value fields only) |
| `shortCode` | Short code identifier |

---

## Generating links

You can create links in two ways:

### Option A — Dynamic Link Tool (manual)

1. Register and log in to your account.
2. Click **Add Project** and fill in your app details — **bundle ID**, store URL, and publication status.
3. Copy your project **`clientId`** and use it in `DynamicLinkConfiguration`.
4. Inside the project, go to **View Links → Add Link**.
5. Set the title, description, and URL scheme. The scheme must exactly match what is configured in `Info.plist`.
6. Add a **JSON Data** payload to control in-app navigation:

```json
{
  "screen": "user_detail",
  "user_id": "u-101"
}
```

7. Share the generated link or use URLs with `?short_code=`.

### Option B — From your app (automatic share)

Call `createPublicLink(_:)` when the user taps Share. The SDK creates the link, returns a share URL, and you open the iOS share sheet. See [Share a link from your app](#share-a-link-from-your-app) above.

The scheme in the tool / request and `Info.plist` must match exactly.

---

## Setup

### Custom URL schemes

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>myapp</string>
</array>
```

Rebuild after any `Info.plist` change.

### Universal Links (HTTPS)

1. Xcode → **Signing & Capabilities** → **Associated Domains**.
2. Add: `applinks:backend-dynamiclink.tecocraft.us` (or your domain).
3. Host `apple-app-site-association` on your domain over HTTPS (no redirects).
4. Rebuild the app.

Example entitlements:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:backend-dynamiclink.tecocraft.us</string>
</array>
```

Universal Links use the same `onSuccess` handler as custom scheme links — no extra SDK code required.

---

## Deferred deep links (app not installed yet)

Use this when your app is **live on the App Store** and you want: tap link → install → open app → land on a specific screen.

**Flow:**

1. User taps your dynamic link (app not installed).
2. User is sent to the App Store and installs the app.
3. On **first launch**, the SDK calls `pending-redirect`.
4. Backend returns the same JSON you attached to the link.
5. `onSuccess` fires — use the same navigation code as a normal deep link.

**Requirements:**

- `clientId` configured in `DynamicLinkConfiguration`
- App published on the App Store at least once
- Bundle ID in Dynamic Link Tool matches your app
- JSON on the link includes navigation fields (`screen`, `user_id`, etc.)
- `SmartLinkingRoot` (or coordinator `start`) is wired before first launch completes

**Retest during development:**

```swift
UserDefaultsFirstInstallStore.resetFirstInstallFlag()
```

Then uninstall the app and repeat the install flow.

**QA tip — test updated routing without a new App Store release:** After the app has been published at least once:

1. Implement the updated navigation logic in your codebase.
2. Completely uninstall the app from your test device.
3. Tap the dynamic link — the device is redirected to the App Store.
4. **Do not install from the store.** Run the app directly from Xcode instead.
5. The SDK delivers the deferred payload and your updated logic runs on first launch.

> This bypass only works after the app has been published at least once.

---

## Testing

### App installed — custom scheme

```sh
xcrun simctl openurl booted "myapp://open?short_code=YOUR_CODE"
```

### App installed — Universal Link

```sh
xcrun simctl openurl booted "https://backend-dynamiclink.tecocraft.us/s/YOUR_SLUG?short_code=YOUR_CODE"
```

### Hosted short-link page (HTML redirect)

```sh
xcrun simctl openurl booted "https://backend-dynamiclink.tecocraft.us/s/YOUR_SLUG"
```

### Deferred deep links

The app must be published on the App Store. Tap the link on a device where the app is not installed — it redirects to the store, and after installation the SDK navigates to the intended screen on first launch.

> If the app is not published, the deferred deep link response will be empty.

### Unit tests

```sh
swift test
```

---

## Example app

A full sample with JSON-driven navigation and an in-app **Share** button lives in [`Example/`](Example/):

```sh
open Example/DynamicLinkExample.xcodeproj
```

Set your `clientId` in `Example/DynamicLinkExample/DemoUser.swift` (`ExampleSDKConfiguration`), then open **Users → User Details → Share** to test link generation and the share sheet.

See [`Example/README.md`](Example/README.md) for screen names, JSON samples, and deferred link testing.

---

## API Reference

### `DynamicLinkConfiguration`

| Property | Description |
|----------|-------------|
| `baseURL` | API root (default: `https://backend-dynamiclink.tecocraft.us/api/links`) |
| `clientId` | **Required.** Unique per project. Sent as `clientId` HTTP header on all API requests |
| `timeout` | Request timeout in seconds (default: `10`) |
| `pathShortCodeHosts` | Hosts where `https://host/{code}` uses the last path segment as short code |

### `SmartLinkingRoot`

| Parameter | Description |
|-----------|-------------|
| `configuration` | `DynamicLinkConfiguration` — must include `clientId` |
| `options` | `SmartLinkingOptions` callbacks |
| `appId` | Defaults to `Bundle.main.bundleIdentifier` |
| `deviceType` | Defaults to `"IOS"` |
| `userAgent` | Device/app string sent with `pending-redirect` |

### `SmartLinkingOptions`

| Callback | Description |
|----------|-------------|
| `onUrl` | Raw URL string before API resolution |
| `onSuccess` | Link resolved; includes JSON payload |
| `onError` | Network, HTTP, or decode errors |
| `onFallback` | Optional — handle store/web fallbacks yourself |
| `onResolvedDestination` | Hosted `/s/{slug}` HTML page resolved to a URL |

### `DynamicLinkClient`

| Method | Description |
|--------|-------------|
| `createPublicLink(_:)` | `POST {baseURL}/public-link` — creates a shareable link (requires `clientId`) |
| `shareURL(forShortCode:)` | Builds `https://host/{shortCode}` from the API response |
| `linkDetails(shortCode:)` | `GET {baseURL}/code/{shortCode}` |
| `fetchDynamicLink(shortCode:)` | Alias for `linkDetails` |
| `pendingRedirect(...)` | `POST {baseURL}/pending-redirect` |
| `trackPendingRedirect()` | Pending redirect using default app identity |
| `consumeFirstLaunchPendingRedirectIfNeeded(...)` | One-time deferred flow with storage |
| `resolveHostedShortLinkPage(at:)` | Parse `/s/{slug}` HTML redirect |
| `extractShortCode(from:)` | Read `short_code` from query string |
| `extractShortCodeWithPathFallback(from:allowedHosts:)` | Query first, then last path segment |
| `isHostedShortLinkPage(_:apiBaseURL:)` | Detect `https://host/s/{slug}` pages |

### `PublicLinkCreateRequest`

| Field | Description |
|-------|-------------|
| `title` | Link title |
| `description` | Link description |
| `iosScheme` | iOS URL scheme (must match `Info.plist`) |
| `androidScheme` | Android scheme (defaults to `iosScheme`) |
| `data` | JSON navigation payload (`[String: DynamicLinkJSONValue]`) |

> Project identity is sent via the `clientId` header on `DynamicLinkConfiguration`, not in the request body.

### `PublicLinkCreateResult`

| Field | Description |
|-------|-------------|
| `shortCode` | Short code returned by the API |
| `shareURL` | Full HTTPS URL to share |

### `DynamicLinkShareSheet`

SwiftUI wrapper for `UIActivityViewController`. Pass the `shareURL` and an optional message string in `items`.

### `DynamicLinkResponse`

| Field | Description |
|-------|-------------|
| `name`, `description` | Link metadata |
| `shortCode` | Short code identifier |
| `customData` | JSON navigation payload from API |
| `payloadJSON` | Pretty-printed JSON for debug |
| `params` | Flat string map for simple fields |
| `iosScheme`, `androidScheme` | Configured schemes |
| `project` | Project metadata (bundle ID, store flags, fallback URLs) |

### First-install storage

| API | Description |
|-----|-------------|
| `UserDefaultsFirstInstallStore.defaultKey` | Storage key for first-launch flag |
| `UserDefaultsFirstInstallStore.hasHandledFirstInstall()` | Whether deferred flow already ran |
| `UserDefaultsFirstInstallStore.resetFirstInstallFlag()` | Clear flag for QA retests |

---

## Requirements

- iOS 15.0+
- Swift 6.3+
- Xcode 16+

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `clientId is required` error | Set `DynamicLinkConfiguration(clientId:)` with your project client id from the Dynamic Link Tool |
| Share / public-link fails | Verify `clientId` header is set and matches your project |
| Link does not open app | Check URL schemes in `Info.plist`; rebuild after changes |
| Universal Link opens Safari only | Verify Associated Domains, AASA file, team ID + bundle ID |
| JSON payload empty | Add JSON Data when creating the link in Dynamic Link Tool |
| HTTP 404 on fetch | `short_code` does not exist in your project |
| Deferred link returns nothing | App must be on App Store; runs once per install; reset first-install flag to retest |
| Deferred deep link response empty | App must be published on the App Store at least once |
| Navigation does not run | Handle routing inside `onSuccess`; check `screen` value in JSON |
| Hosted `/s/…` parse fails | Page must include a recognizable JS or meta redirect |

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT © Tecocraft

## Support

- Email: support@tecocraft.com
- Issues: [GitHub Issues](https://github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK/issues)
- Discussions: [GitHub Discussions](https://github.com/chiragjanjmeratecocraft/IOS-Dynamic-Link-SDK/discussions)
