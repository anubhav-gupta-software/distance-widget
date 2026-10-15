# Distance Widget

Distance is an iPhone app for two people. You pair with an invite code, each of you chooses to share an approximate location, and a Home Screen and Lock Screen widget shows how far apart you are, the other person's city, their local time, and a short status. It does not show the weather.

The location that leaves the phone is rounded to about a kilometer. The city and time zone go with it. The street does not.

## What the app does

- Onboarding asks for a name, then whether to share an approximate location. You can skip sharing and turn it on later.
- Pairing creates a six-character invite code, or joins a code someone sent you. Codes leave out lookalike characters so they are easier to read aloud. A link of the form `distancewidget://join/CODE` opens the join screen.
- The home screen shows the distance, their city, their local time ("their evening", and a clock), and a status such as "Across town" or "A flight apart".
- A pause switch stops sending updates. Your own widget can still show the last distance. Theirs says you paused, and drops the place.
- Privacy controls cover the opt-in, pause, kilometers or miles, what is shared, unpair, and erase-on-this-phone.
- Widgets: Home Screen small, medium, and large, plus Lock Screen circular, rectangular, and inline.
- A sample partner (Lisbon, Tokyo, Mexico City, or Nairobi) is stored only on this phone so you can see the widget before anyone joins.

There is no account, no map, and no push notification. The widget updates when the app writes a new location, and on a timeline of about every 30 minutes. iOS decides the real refresh time.

## What you need

- A Mac with Xcode 16 or newer
- An iPhone running iOS 17 or newer
- A free Apple ID (a Personal Team in Xcode)
- Optional: a free Firebase project, only if two phones should stay in sync

A paid Apple Developer Program membership is not required to install this on your own phone. It is required for TestFlight, CloudKit, and push notifications. This project does not use CloudKit or push.

## Install it on your iPhone with a free Apple ID

Provisioning from a free Apple ID lasts 7 days, and you can only have a few apps installed this way. When the app expires, run it from Xcode again.

1. Install Xcode from the Mac App Store and open it once so it can finish installing components.
2. In Xcode, sign in with your Apple ID: Settings → Accounts → add your Apple ID. The team will show up as "Personal Team".
3. Edit `Config/Shared.xcconfig` before the first build. Change both lines to something that belongs to you:

   ```
   APP_BUNDLE_ID = com.yourname.distancewidget
   APP_GROUP_ID = group.com.yourname.distancewidget
   ```

   Use your own name or initials. A free account can register a bundle ID and an App Group only if no other team has claimed them. The widget's bundle ID is `APP_BUNDLE_ID` plus `.widget`, so you only edit the one prefix.

4. Open `DistanceWidget.xcodeproj` (not the `project.yml`).
5. Select the **DistanceWidget** scheme and your iPhone as the run destination. The iPhone has to be unlocked and trusted ("Trust This Computer").
6. Select the **DistanceWidget** target, then Signing & Capabilities. Check "Automatically manage signing" and choose your Personal Team. Do the same for the **DistanceWidgetExtension** target.
7. Both targets already include the App Groups entitlement, and Apple's capability list includes App Groups for a free account. If Xcode says the group is not registered, click the App Groups capability and let it add `group.com.yourname.distancewidget` (whatever you set in the xcconfig). The app and the widget must use the same group, or the widget cannot see the location.
8. Press Run. The first build takes a minute because it compiles the local `DistanceCore` package.
9. On the iPhone, if iOS blocks the launch, open Settings → General → VPN & Device Management, tap the developer certificate, and trust it.
10. Add the widget. Home Screen: long-press, tap the plus, search for Distance. Lock Screen: long-press the Lock Screen, tap Customize, then add Distance under the clock or as an inline line.

The home screen name under the icon is **Distance**.

### If signing fails

- **"Failed to register bundle identifier"** or the identifier is not available. Change `APP_BUNDLE_ID` and `APP_GROUP_ID` in `Config/Shared.xcconfig` to something more unique, then clean the build folder (Product → Clean Build Folder) and run again.
- **"Personal development teams do not support the App Groups capability."** Apple's current capability list includes App Groups for a free account, and that is the error older Xcode versions showed. Update Xcode. If a current Xcode still refuses the capability, a paid membership is required for the widget to share data. You can still install the app by clearing `CODE_SIGN_ENTITLEMENTS` on both targets. The screens work. The widget will not see this phone's saved location until the group is entitled.
- **"Unable to install"** after a previous attempt. Delete the app from the phone and run again. Free accounts also cap how many apps can be installed at once.
- The widget target must use the same team as the app. If only one target is signed, the build fails while embedding the extension.

## Try it on one phone

Out of the box, sync is local. Nothing is uploaded.

1. Finish onboarding. Sharing can wait if you only want to preview.
2. Open Pairing and pick a sample partner.
3. Add the widget. You should see their city and local time. The distance appears after you allow location, because the app needs your rounded location as the other end of the measurement.

An invite code created in local mode stays on this phone. Another phone cannot redeem it until you turn on Firebase below.

## Sync two phones with Firebase

The app talks to Firebase Realtime Database over plain HTTPS. There is no Firebase SDK, no `GoogleService-Info.plist`, and no API key. Leave `firebaseAuthToken` empty if you use the test rules.

These rules are open on purpose so a private test works without setting up auth. Anyone who can guess the database URL can read and write `/distanceWidget/v1`. Use a project you don't store anything else in, and don't ship those rules.

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com). The free Spark plan is enough.
2. Build → Realtime Database → Create database. You can start in test mode or locked mode. You will replace the rules in the next step.
3. Open the Rules tab and paste `firebase/database.rules.json`. Publish.
4. Copy the database URL. It looks like `https://your-project-default-rtdb.firebaseio.com`.
5. In `Shared/SyncSettings.swift`, set:

   ```swift
   static let backend: SyncBackend = .firebase
   static let firebaseDatabaseURL = "https://your-project-default-rtdb.firebaseio.com"
   ```

6. Build and run on both phones. One person creates a code and shares it. The other enters it. Each phone publishes a rounded location, and the widget reads the App Group plus, on its own timeline, the partner record from Firebase.

If the database refuses the request, the home screen shows a short error. Check the URL, that the rules were published, and that the URL has no trailing path.

An optional `firebaseAuthToken` is sent as Firebase's `auth` query parameter. You only need it if you replace the open rules with rules that require auth. This project does not include Firebase Authentication.

### CloudKit

CloudKit is not wired up. A free Personal Team cannot use the iCloud capability, so a CloudKit container would stop the project from installing with a free Apple ID. The sync protocol is small (`saveInvite`, `loadInvite`, `saveSnapshot`, `loadSnapshot` in `Shared/SyncClient.swift`). A later CloudKit client can store the same JSON records in a private database once you are on a paid membership.

## How location sharing works

- The system prompt asks for location. The app requests Always so the widget can stay current when Distance is closed. If you grant While Using, updates happen when the app is open.
- Accuracy is about a kilometer. Before anything is saved or sent, the coordinate is rounded to two decimal degrees (about 1.1 km of latitude).
- Reverse geocoding keeps the city (or region) and the time zone. Street fields are discarded.
- Always authorization uses significant-location updates and shows the system location indicator. That is deliberate.
- Pause, or turning sharing off, publishes a snapshot with no coordinate and no city, and `sharingPaused` set. The other phone's widget stops showing a distance.
- Erase deletes the on-phone copy. It does not delete a Firebase node. Unpair and, if you care, delete the data in the Firebase console.

## Project layout

```
Config/Shared.xcconfig          bundle id and App Group, edit this first
project.yml                     XcodeGen spec
DistanceWidget.xcodeproj        generated project, already committed
DistanceCore/                   distance, status text, invite codes, JSON
DistanceWidget/                 the app
DistanceWidgetExtension/        Home Screen and Lock Screen widgets
Shared/                         App Group store, sync client, colors
firebase/database.rules.json    open test rules
```

Shared Swift files are compiled into both the app and the widget. `DistanceCore` is a local Swift package linked by both targets, and it has no UIKit dependency.

Regenerate the project after you change `project.yml`:

```
brew install xcodegen
xcodegen generate
```

This repo was generated with XcodeGen 2.46.0. Check the distance helpers on a Mac or Linux with Swift:

```
cd DistanceCore
swift test
```

## Move to TestFlight later

TestFlight needs the Apple Developer Program (paid, currently $99/year). A free Personal Team cannot upload builds.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs).
2. In [App Store Connect](https://appstoreconnect.apple.com), create an app whose bundle ID matches `APP_BUNDLE_ID`.
3. In the developer portal, confirm the App ID and the widget's App ID (`APP_BUNDLE_ID.widget`) both have the App Group enabled, and that the group id matches `Config/Shared.xcconfig`. Xcode's automatic signing often does this once the account is paid.
4. On the DistanceWidget scheme, choose Any iOS Device (arm64). Product → Archive.
5. Distribute App → App Store Connect → Upload.
6. In App Store Connect, open TestFlight. Internal testers (App Store Connect users) can install without review. External testers go through a short Beta App Review.
7. Background location and widgets work for testers the same way they do from Xcode. Push is still not part of this app, so the widget will not update the instant the other person moves. Adding push later requires the Push Notifications capability, which a paid membership provides.
8. Before an external beta, replace the open Firebase rules. The privacy story in the app (approximate location, pause, erase) should match whatever you write in the App Store privacy questionnaire. The app target ships a privacy manifest for coarse location, name, and UserDefaults.

Archive using the same bundle IDs you tested with, or create new ones and update `Config/Shared.xcconfig` before you archive. The App Group has to move with them.
