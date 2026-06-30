# DynamicLinkExample

Sample iOS app showing how **DynamicLinkSDK** handles deep links, Universal Links, and deferred deep links — and how JSON from the Dynamic Link Tool drives navigation to specific screens.

---

## What this example demonstrates

| Feature | What happens |
|---------|----------------|
| **Deep link (app installed)** | User taps link → app opens → JSON fetched → navigates to the right screen |
| **Universal Link (HTTPS)** | Same flow using `https://backend-dynamiclink.tecocraft.us/...` |
| **Deferred deep link (app not installed)** | User taps link → App Store → install → first open → same JSON → same screen |
| **Custom URL scheme** | Links like `deeplinkexample://open?short_code=...` |

---

## Open and run

```sh
open Example/DynamicLinkExample.xcodeproj
```

1. Select the **DynamicLinkExample** scheme  
2. Run on an iOS Simulator (**iOS 16+** for this demo’s navigation UI)  
3. Use the **Home** tab to inspect link events and run tests  

**Bundle ID:** `com.tecocraft.demo` — register this in the Dynamic Link Tool before testing real links or deferred redirects.

---

## App screens

The example includes four areas you can navigate to:

| Screen | Purpose |
|--------|---------|
| **Home** | Link status, simulate navigation, test commands |
| **All Users** | List of demo users |
| **User Details** | Profile for one user |
| **User Portfolio** | Portfolio items for one user |

Demo user IDs: `u-101`, `u-102`, `u-103`, `u-104`.

---

## JSON in the Dynamic Link Tool

When you create a link, add **JSON Data** to control where the app goes after the link is opened.

| `screen` value | Opens | Required fields |
|----------------|-------|-----------------|
| `all_users` or `users` | All Users list | — |
| `user_detail` or `user_details` | User Details | `user_id` |
| `user_portfolio` or `portfolio` | User Portfolio | `user_id` |

### Examples

**All users**

```json
{
  "screen": "all_users"
}
```

**Specific user profile**

```json
{
  "screen": "user_detail",
  "user_id": "u-101"
}
```

**User portfolio**

```json
{
  "screen": "user_portfolio",
  "user_id": "u-102"
}
```

After the link resolves, the app reads this JSON and pushes the matching screen automatically.

---

## How navigation works in code

The app uses three pieces:

1. **`SmartLinkingRoot`** — listens for links and fetches payload from the backend  
2. **`DeepLinkRouter`** — reads `screen` and `user_id` from JSON  
3. **`AppNavigationStore`** — pushes the correct screen  

Entry point (`DynamicLinkExampleApp.swift`):

```swift
SmartLinkingRoot(
    options: SmartLinkingOptions(
        onSuccess: { data in
            store.handleDeepLink(data)
        }
    )
) {
    ContentView()
}
```

Routing (`DeepLinkRouter.swift`) matches `screen` from JSON and returns the destination. You can copy this pattern into your own app and change screen names and IDs to match your product.

---

## Testing

### 1. Simulate navigation (no backend link needed)

On the **Home** tab, use **Simulate navigation** buttons. These jump directly to a screen so you can verify UI without a real `short_code`.

### 2. Deep link with a real short code

Create a link in the Dynamic Link Tool, copy the **short_code**, then run:

```sh
# Custom URL scheme
xcrun simctl openurl booted "deeplinkexample://open?short_code=YOUR_CODE"

# Alternate scheme (also registered in Info.plist)
xcrun simctl openurl booted "songLatest://open?short_code=YOUR_CODE"
```

Expected: **Home** tab shows URL and JSON payload; app navigates to the screen defined in your JSON.

### 3. Universal Link (HTTPS)

Ensure **Associated Domains** is enabled (`applinks:backend-dynamiclink.tecocraft.us` in entitlements) and your domain hosts a valid `apple-app-site-association` file.

```sh
xcrun simctl openurl booted "https://backend-dynamiclink.tecocraft.us/s/YOUR_SLUG?short_code=YOUR_CODE"
```

Or tap the HTTPS link in Safari on a device with the app installed.

### 4. Deferred deep link (app not installed yet)

Use this when your app is **live on the App Store** and you want install-from-link → open app → land on a specific screen.

**Flow:**

1. Uninstall the app from the test device  
2. Tap your dynamic link (user is sent to the App Store)  
3. Install and open the app  
4. On **first launch**, the SDK calls `pending-redirect`  
5. Backend returns the same JSON you set on the link  
6. `onSuccess` runs → app navigates to the target screen (e.g. User Details for `u-101`)

**Requirements:**

- App published on the App Store at least once  
- Bundle ID in Dynamic Link Tool matches `com.tecocraft.demo`  
- JSON on the link includes `screen` and any IDs you need  

**Retest deferred flow:**

- Tap **Reset first-install flag** on the Home tab, or run:
  ```swift
  UserDefaultsFirstInstallStore.resetFirstInstallFlag()
  ```
- Uninstall the app and repeat the steps above  

**QA note:** After the app has been published once, you can uninstall, tap the link, then run from Xcode instead of installing from the store — the deferred payload may still be delivered on first launch.

---

## Setup checklist (for your own app)

Copy this example into your project:

| Step | Action |
|------|--------|
| 1 | Add **DynamicLinkSDK** via Swift Package Manager |
| 2 | Register URL schemes in **Info.plist** (must match Dynamic Link Tool) |
| 3 | For Universal Links: add **Associated Domains** and host AASA on your domain |
| 4 | Wrap your root view with **`SmartLinkingRoot`** |
| 5 | In **`onSuccess`**, read `data.customData` or `data.payloadJSON` and navigate |
| 6 | Register your **bundle ID** in the Dynamic Link Tool |
| 7 | Create links with JSON (`screen`, `user_id`, etc.) |

---

## URL schemes in this example

Registered in `Info.plist`:

- `deeplinkexample`
- `songLatest`
- `dynamiclinkdemo`

Use the same scheme values when creating links in the Dynamic Link Tool.

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| No navigation after link | JSON `screen` value matches `DeepLinkRouter` rules; use a valid `short_code` |
| Empty JSON payload | Link must include JSON Data in Dynamic Link Tool; API field is `data` |
| HTTP 404 | `short_code` does not exist in your project |
| Deferred link does nothing | App not on App Store yet, or first-install flag already set — reset and reinstall |
| Universal Link opens Safari only | Associated Domains, AASA file, correct team ID and bundle ID |
| Link works in simulator but not device | Schemes in Info.plist; rebuild after plist changes |

---

## Project structure

```
DynamicLinkExample/
├── DynamicLinkExampleApp.swift   # SmartLinkingRoot + onSuccess
├── ContentView.swift             # TabView + navigation stack
├── HomeTabView.swift             # Debug UI and test buttons
├── DeepLinkRouter.swift          # JSON → screen mapping
├── AppNavigationStore.swift      # Navigation state
├── AppRoute.swift                # Route enum
├── AllUsersView.swift
├── UserDetailView.swift
├── UserPortfolioView.swift
├── DemoUser.swift                # Sample user data
├── Info.plist                    # URL schemes
└── DynamicLinkExample.entitlements  # Universal Links domain
```

For full SDK installation and API details, see the [main README](../README.md).
