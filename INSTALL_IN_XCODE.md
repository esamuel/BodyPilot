# BodyPilot AI — Xcode Brand Pack

This pack is built from the approved watch/runner/route logo.

## Included

- `Assets.xcassets/AppIcon.appiconset` — iPhone/iPad/App Store icons
- `Assets.xcassets/WatchAppIcon.appiconset` — Apple Watch icon sizes
- `Assets.xcassets/BodyPilotLogo.imageset` — reusable logo for SwiftUI screens
- Brand color assets
- `AccentColor.colorset`
- `BodyPilotBrand.swift`
- 1024×1024 master icon

## Add to Xcode

### Easiest method

1. Unzip this package.
2. Open your BodyPilot project in Xcode.
3. In Finder, open the extracted `BodyPilot_Xcode_Brand_Pack`.
4. Drag `Assets.xcassets` into the Xcode project navigator.
5. If Xcode asks, choose **Copy items if needed**.
6. Drag `BodyPilotBrand.swift` into the main iOS target.
7. In the iOS target settings, make sure **App Icons Source** points to `AppIcon`.
8. In the Watch target settings, select `WatchAppIcon` as the Watch app icon asset.

If your project already has `Assets.xcassets`, do NOT replace the whole catalog blindly.
Instead drag the individual folders inside this pack's `Assets.xcassets` into your existing asset catalog.

## SwiftUI usage

Logo:

    Image("BodyPilotLogo")
        .resizable()
        .scaledToFit()

Brand colors:

    Text("BodyPilot AI")
        .foregroundStyle(BodyPilotBrand.deepBlue)

    Button("Start Workout") { }
        .tint(BodyPilotBrand.pilotBlue)

Tagline:

    Text(BodyPilotBrand.tagline)

## Brand colors

- Pilot Blue — #0A6BFF
- Deep Blue — #0047D1
- Route Teal — #00E0B8
- Sky Mist — #E8F2FF
- Graphite — #111827
- Cool Gray — #6B7280
- Light Gray — #F3F4F6
- White — #FFFFFF

## Brand line

**BodyPilot AI**

**Your body. Your plan. Every day.**

## Important

Keep the icon artwork unchanged. Do not stretch, recolor, crop, or place it on a busy image.

## Body Insights Visual Extension

The approved BodyPilot logo and master brand colors remain unchanged.

Dedicated insight pages may add semantic secondary accents such as:
- Sleep Violet
- Movement Amber
- Recovery Green
- Heart Coral

Add those as named color assets rather than hard-coded Swift color literals.

All insight-page illustrations should be original BodyPilot artwork, preferably implemented as reusable SwiftUI illustration scenes under `Core/Illustrations`.

Do not recolor or modify the approved app icon to match individual insight pages.
