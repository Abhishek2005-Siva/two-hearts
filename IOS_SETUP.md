# iOS setup

The `ios/` project scaffolding, permission strings, and background modes are
already committed. The remaining steps **require a Mac with Xcode** — they
can't be done from the Linux dev container this repo is usually worked on
from, and nothing below has been built or run, only configured.

## 1. Firebase iOS app (required — the app won't start without it)

`main.dart` calls `Firebase.initializeApp()` with no explicit options, so on
iOS it reads `GoogleService-Info.plist` the same way Android reads
`google-services.json`.

1. Firebase Console → your project → Add app → iOS.
2. Bundle ID: `com.twohearts.twoHearts` (confirm against
   `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` —
   use whatever is actually there).
3. Download `GoogleService-Info.plist`.
4. Open `ios/Runner.xcworkspace` in Xcode and drag the file into the
   `Runner` group, ticking "Copy items if needed" and the Runner target.
   Dragging it in via Xcode matters — copying it in with `cp` alone leaves
   it out of the target and Firebase will fail at runtime.

## 2. Push notifications (APNs)

FCM on iOS goes through APNs, which needs a paid Apple Developer account:

1. Xcode → Runner target → Signing & Capabilities → add **Push
   Notifications** and **Background Modes** (Remote notifications + Audio
   are already declared in `Info.plist`).
2. Apple Developer portal → Keys → create an **APNs Auth Key** (`.p8`).
3. Firebase Console → Project settings → Cloud Messaging → iOS app → upload
   that `.p8` with its Key ID and your Team ID.

Until this is done, everything works except push notifications.

## 3. Build

```sh
cd ios && pod install && cd ..
flutter build ios
```

## Known gaps / things to verify on device

These were configured but never exercised, because iOS can't be built here:

- **Android-only widget**: the home-screen drawing widget
  (`DrawingWidgetProvider.kt`, `home_widget`) is implemented for Android
  only. On iOS it needs a separate WidgetKit extension in Swift — not
  written. The in-app drawing screen still works; only the OS widget is
  missing.
- **Screen sharing**: `FOREGROUND_SERVICE_MEDIA_PROJECTION` is an Android
  concept; the iOS equivalent is ReplayKit and is not implemented.
- **Deployment target** is 13.0. If CocoaPods complains about a Firebase
  pod needing something newer, raise it in both the Podfile and Xcode's
  Runner target.
- Camera, mic, photo library, and location prompts should be checked once
  on a real device — the usage strings are in `Info.plist`, but iOS
  terminates on any permission used without one, so a missed capability
  shows up as a hard crash rather than a denied prompt.
