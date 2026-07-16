# Two Hearts — context for Claude Code

A private Flutter app for one specific couple (LDR-friendly): chat, shared
journal, letters (time-locked), memories/photos, a shared 3D room, recipes,
"Wildcards" favor cards, games, and more. Firebase-backed (Auth, Firestore,
FCM, Cloudinary for media). See `SETUP.md` for first-time Firebase setup and
`DEBUGGING.md` for the Codespace+Tailscale phone-debugging workflow — this
file is about how the code is put together and how to work in it.

## Environment reality check

This repo is very often worked on from a sandboxed dev container with **no
Android emulator and no physical device attached**. In that situation:
- The only real verification available is `flutter analyze --no-fatal-infos`
  and a successful GitHub Actions build (`Build APK` workflow).
- You **cannot** visually confirm UI/animation/3D-scene correctness. Say so
  explicitly when reporting work instead of claiming it "looks right."
- `flutter pub get` and `flutter analyze` work fine offline-ish (need network
  for pub.dev only). `flutter build apk` is what CI runs — mirror that
  locally if you want a stronger signal before pushing.

## Standard workflow for any change

1. Make the change.
2. `export PATH="$PATH:/home/xxorks/flutter-sdk/flutter/bin"` if `flutter`
   isn't already on PATH, then `flutter analyze --no-fatal-infos` — fix
   everything except the couple of pre-existing unrelated info-level lints
   (`unnecessary_import` in `app_router.dart`, `use_null_aware_elements` in
   `firestore_service.dart`) that predate most work here.
3. Commit with a `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
   trailer. Only commit when the user actually asked for it.
4. `git push origin main`, then `gh run list --branch main --limit 1` to get
   the run id, then `gh run watch <id> --exit-status` (backgroundable) to
   confirm CI is green before telling the user it's done.
5. The CI workflow (`.github/workflows/build.yml`) publishes a rolling
   GitHub Release (tag `latest-build`) and sends an FCM push (topic
   `dev_builds`, gated to one developer email in `main.dart`) with a direct
   APK download link — that's how the build reaches a phone.

## Architecture conventions (follow these, don't reinvent)

- **State**: Riverpod, classic `Provider`/`StreamProvider` (not codegen,
  not Notifier, with one legacy `ThemeModeNotifier` exception). Every
  couple-scoped Firestore collection gets one `StreamProvider` in
  `lib/core/providers/providers.dart` shaped like:
  ```dart
  final xProvider = StreamProvider<List<X>>((ref) {
    final coupleId = ref.watch(coupleIdProvider);
    if (coupleId == null) return const Stream.empty();
    return ref.read(firestoreServiceProvider).watchX(coupleId);
  });
  ```
- **Firestore**: one big `FirestoreService` class in
  `lib/core/firebase/firestore_service.dart` (no repository-per-feature
  split). Collections hang off `couples/{coupleId}/<name>`. Conventions:
  `.set(model.toMap())` for new docs with a client-generated `Uuid().v4()`
  id, `.set(data, SetOptions(merge:true))` for create-or-update singleton
  docs (room style, cinema/listen sessions), `.update({...})` for targeted
  field mutations, `.add()` only for append-only logs. Singleton per-couple
  docs (style, session state) get a private `_xDoc(coupleId)` ref helper.
- **Models** (`lib/core/firebase/models.dart`): every model has
  `factory X.fromDoc(DocumentSnapshot doc)` (id always from `doc.id`, never
  re-stored in the map) and `Map<String,dynamic> toMap()`. `DateTime` via
  `Timestamp.fromDate`/`(x as Timestamp?)?.toDate() ?? DateTime.now()`.
- **Routing**: GoRouter, one flat `routes:` list inside a single
  `ShellRoute` (`lib/core/router/app_router.dart`). The 5 bottom-nav tabs
  use `pageBuilder: (_, _) => _tabPage(const XScreen())` (shared
  fade+scale transition); everything else (pushed sub-features) uses plain
  `builder:`. `/cinema` is the one screen outside the shell (fullscreen).
- **Theme/shared widgets** (`lib/core/theme/app_theme.dart`): `AppColors`
  (dark romantic palette, rose/coral/gold accents + per-couple
  `kCoupleAccents`), `SquishyTap` and `GradientButton` are the two shared
  tap primitives used almost everywhere — both now support an optional
  `cuteStickers: List<String>?` param that bursts a couple of emoji up
  from the widget on tap (via `FloatingStickers.burst`, see below). Use it
  on primary/completing actions (send, save, give), not on every
  navigational tap.
- **Delight layer** (`lib/core/delight/delight.dart`): `DelightHaptics`
  (named haptic patterns), `FloatingStickers.burst(context, stickers:,
  count:, origin:)` (small rising/fading emoji particles from a point —
  reused by `SquishyTap`/`GradientButton`), `FlyAway`, `HeartBombardment`,
  `TopBanner`, `SeasonalDrift`. Governing rule stated in the file itself:
  "one delightful thing at a time" — don't stack effects.
- **Honesty principle, enforced throughout**: never fabricate stats,
  detection, or feature state. Real counts only. When something can't be
  verified (e.g. a partner's exact online status), don't fake it.

## Feature map (routes → what/why)

- `/room` — home tab: avatar characters, mood bubbles, polaroid strip of
  recent memories, gift-sending, presence. `room_screen.dart`.
- `/room/decorate` — **shared 3D room** (see dedicated section below).
- `/chat` — main chat, snaps, whispers, voice notes, replies/edits,
  read-receipts (see gotcha below), backgrounds.
- `/memory`, `/memory/:id` — photo/video wall, collections, favorites.
- `/together` — hub screen linking to Journal, Letters, Games, Movie
  Night (`/cinema`), Bucket List, Destinations, Books, **Recipes**,
  **Wildcards**, Quick Picks (Random Question, Love Quiz, Mood Check,
  Coin Toss).
- `/together/journal` — bookshelf-styled journal (real background image
  `assets/images/journal_bookshelf_bg.png`, year-grouped dynamic-capacity
  shelves, book-spine entries, "Memory of the Day", real stats).
- `/together/recipes` — same bookshelf visual language as Journal, shelved
  by meal category instead of year; structured editor (category + 
  ingredients + instructions) instead of free-form rich text.
- `/together/letter/new` — time-locked letters (tomorrow/next
  week/birthday/anniversary/open-when-sad/custom date), parchment editor.
  Letters sheet shows only a small aggregate "opened N times" line, no
  per-letter Sent tab (removed per feedback — keep it that way).
- `/together/wildcards` — "special favor cards" (Joker/King/Queen/Jack/
  numbered playing cards, drawn at random *purely for visual flavor*, not
  gameplay-restrictive). **Only one hardcoded account
  (`_kGranterEmail` in `wildcards_screen.dart`) can send a card directly**;
  the other partner can only *request* one, which the granter approves
  (approval opens the same compose flow) or declines. This gating is
  client-side only (no Firestore security rule enforcement) — acceptable
  for this app's threat model, same pattern as the `dev_builds` FCM topic
  gate in `main.dart`.
- `/books` — shared reading wishlist / read-together tracker with real
  PDF-in-app reading and per-partner page progress.
- `/games`, `/dates`, `/places`, `/listen`, `/you`, `/notifications` —
  games hub, date-idea spinner, destinations map, Spotify Listen
  Together (OAuth PKCE), profile/settings, notifications inbox.

## The shared 3D room (`/room/decorate`) — read this before touching it

**This was rebuilt from scratch once already.** First version was a
hand-rolled isometric (2:1) CustomPainter renderer with a 222-item vector
catalog, later upgraded to use real Kenney CC0 sprite art for ~34 items.
The user then explicitly asked to throw all of that away for **genuine
3D**, scoped to "basic furniture only." Current implementation:

- **Rendering**: Three.js r128 + `OrbitControls` (classic non-module
  build, bundled locally at `assets/room3d/three.min.js` and
  `OrbitControls.js` — pulled from jsDelivr's mirror of the official
  `mrdoob/three.js` GitHub repo, user-approved source). Pinned to r128
  specifically because it still ships the classic global-`<script>`
  build; newer Three.js is ES-modules-only, more fragile inside a
  WebView. The whole scene lives in one file, `assets/room3d/index.html`.
- **Host**: `lib/features/room/home_decorate_screen.dart` is a
  `WebViewController` (`webview_flutter`) that loads that HTML via
  `loadFlutterAsset` (correctly resolves the sibling `.js` files —
  `loadHtmlString`/`file://` would not). A `JavaScriptChannel` named
  `FlutterBridge` carries JS→Flutter events (`ready`, `placed`,
  `selected`); Flutter calls back into JS via `runJavaScript` for
  `loadRoom(json)`, `setStyle(...)`, `enterPlacementMode(type)`,
  `exitPlacementMode()`, `rotateItemMesh(id)`.
- **Data model**: `Furniture3DItem` (continuous `x`/`z` meters +
  `rotationY` radians, not a tile grid — replaced the old
  `HomeDecorItem`'s col/row/rotation shape) and `HomeRoomStyle`
  (floor/wall/lighting ids) in `models.dart`. Firestore collection
  `couples/{coupleId}/homeDecor` + singleton doc
  `couples/{coupleId}/homeRoom/style` — same collection names as the old
  isometric version, but the *shape* changed, so any decor placed under
  the old system is orphaned/unreadable now (expected, user-approved).
- **Sync strategy**: full-rebuild-on-change, not incremental diffing.
  Every Firestore stream update calls `window.loadRoom(...)` with the
  *entire* current item list and JS tears down and rebuilds the whole
  furniture group. Deliberately simple because nobody can visually
  iterate on incremental-diff bugs in this environment.
- **Interaction correctness gotcha already fixed once**: naive
  `pointerdown`-triggers-placement logic collides with OrbitControls'
  own drag-to-orbit gesture. Current code tracks down-position and a
  `TAP_SLOP` (8px) threshold in the JS, only firing placement/selection
  on `pointerup` if the pointer never moved past that threshold — don't
  regress this if you touch the interaction code.
- **Furniture set is intentionally small**: sofa, bed, coffee_table,
  bookshelf, lamp (has a real attached `THREE.PointLight`), plant, rug,
  chair — all built from primitive geometry (boxes/cylinders/spheres),
  no external 3D models. "Basic furniture only" was explicit; don't
  balloon this back into a huge catalog without being asked.
- **Lighting/palette follow the `interior-design-expert` skill's actual
  guidance** (see below): layered ambient(hemisphere)/natural(directional,
  shadow-casting)/accent(warm point light) lighting, Scandi/Japandi
  warm-neutral base blended with the app's rose/coral/gold accents, real
  circulation/clearance proportions for room sizing.
- Entry point is a chair-icon button on `/room` (`room_screen.dart`),
  next to the settings gear — the original avatar/mood Room scene is
  otherwise untouched.

## Installed skills

- `.claude/skills/interior-design-expert/` — space planning, Munsell
  color theory, IES lighting standards, style references. Used for the
  3D room's lighting/palette/proportions. Re-consult it before making
  further interior/room-visual changes.
- `.claude/skills/ui-ux-pro-max/` — searchable UI/UX design database
  (styles, palettes, typography, UX guidelines, motion, stacks including
  Flutter). SKILL.md only was installed (no `data/`/`references/`/
  `scripts/` payload) — the search-script workflow described in it isn't
  actually runnable in this repo; treat it as reference guidance only
  unless someone adds the supporting files.

## Things that look like bugs but are intentional

- Letters' view-count is a single aggregate line ("opened N times
  total"), not a per-letter Sent tab. Was built, then explicitly removed.
- Wildcards' random card face is cosmetic flavor only — it does not gate
  or suggest what favor text can be written.
- The chat "seen" indicator only flips once the *app itself* is in
  `AppLifecycleState.resumed` (see `_ChatScreenState` in
  `chat_screen.dart`) — a Firestore listener can fire while backgrounded,
  and that must not mark messages read.
- Front-camera Snap photos are explicitly flipped after capture
  (`snap_camera_screen.dart`) to match the mirrored live preview — Android
  WebView/camera capture is not mirrored by default even though the
  preview usually is.
