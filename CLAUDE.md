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
- **Routing**: GoRouter, `StatefulShellRoute.indexedStack`
  (`lib/core/router/app_router.dart`) with one `StatefulShellBranch` per
  bottom-nav tab, each owning its own independent Navigator — this is
  *not* a plain `ShellRoute` (was, until this stopped preserving
  navigation state across tab switches; see Session history). Every route
  lives in exactly one branch's `routes:` list, assigned to whichever tab
  it's most naturally reached from; `MainShell` switches tabs via
  `navigationShell.goBranch(index)`, never `context.go(path)`. A route
  pushed from a *different* tab than the one that owns it (e.g. Listen
  Together, reachable from both Room and Chat) will switch the active tab
  to wherever that route lives — expected StatefulShellRoute behavior,
  not a bug. The 5 bottom-nav tab roots use
  `pageBuilder: (_, _) => _tabPage(const XScreen())` (shared fade+scale
  transition); everything else (pushed sub-features) uses plain
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
- **Presence/activity**: `MainShell` already writes coarse tab-level
  presence (`presence.$uid`/`lastSeen.$uid`/`sections.$uid` on the couple
  doc, via `setPresence`). Finer-grained "what are they actually doing"
  (e.g. "Reading The Great Gatsby") is a separate `activityLabel.$uid`
  field, written by the specific screen via the `ActivityAnnouncer` mixin
  (`lib/core/presence/activity_announcer.dart`) — `with ActivityAnnouncer`
  + call `announceActivity('...')` in `initState` (or again later once a
  dynamic label, like a title, is known); it auto-clears on dispose. Wired
  into every Together sub-screen, Books' PDF reader, Memory/Calendar
  detail, and House Decorate. `_PartnerActivityBanner` on the Room screen
  merges this with Chat's existing typing/recording/uploading state into
  one priority-ordered display, shown *only* while the partner is
  genuinely online (`partnerOnlineProvider`) — never fabricated, and never
  shown for an offline partner.

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
- `.claude/skills/apple-design/` — cross-platform UI/UX design reviewer
  grounded in Apple HIG principles, bundles real reference docs
  (`references/hig/`). Use for design-review/audit requests, not just
  visual/interior work (that's `interior-design-expert`'s job).
- `.claude/skills/flutter-patterns/` — reference docs
  (`patterns/flutter-{widget,testing,performance,security,animation}-patterns.md`)
  for Flutter-specific implementation patterns and checklists.
- `.claude/skills/flutter-tester/` — Riverpod/Mockito-aware Flutter
  testing patterns (Given-When-Then, layer isolation, GetIt/
  SharedPreferences/FakeDatabase setup). Note: this project currently has
  **no test suite** (see "Environment reality check" above — verification
  is `flutter analyze` + CI build only), so this is reference-only until
  someone actually adds tests.
- `.claude/skills/owasp-mobile-security-checker/` — OWASP Mobile Top 10
  audit skill with real Python scanner scripts (`scripts/`), covers
  hardcoded secrets, insecure storage, weak crypto, network issues, etc.
  Bear in mind this app has a couple of *intentional* client-side-only
  gates already accepted for its threat model (Wildcards' `_kGranterEmail`,
  `dev_builds` FCM topic) — don't treat those as findings without
  re-reading why they're documented as deliberate above.
- All four added from small, single-purpose upstream repos after
  checking each actually ships real content (not just a description) —
  skipped a fifth candidate (`vp-k/flutter-craft`) because it was a heavy
  15-skill opinionated multi-agent SDLC methodology (worktrees, parallel
  agents, its own planning process) that would impose a workflow at odds
  with how this repo is actually worked on, not just reference material.

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

## Session history / feature timeline (why things look the way they do)

Roughly chronological. Written so a fresh agent understands *why* a
screen looks the way it does, not just what the code does.

### CI/CD and phone delivery pipeline
- `.github/workflows/build.yml` runs `flutter build apk` on every push to
  `main`, zips the resulting `app-release.apk` into `app-release.zip`
  (explicit user ask — download link is a zip, not the raw APK), then
  `ncipollo/release-action@v1` publishes/overwrites a single rolling
  GitHub Release tagged `latest-build` (`allowUpdates: true,
  removeArtifacts: true, makeLatest: true`) with that zip — one permanent
  download URL, not per-commit releases.
- `.github/scripts/notify_build.js` (plain Node, no npm deps — uses
  built-in `crypto`/`fetch`) JWT-signs the Firebase service account,
  exchanges for an OAuth token, and POSTs an FCM v1 `messages:send` to
  topic `dev_builds` with a `data` payload (`type: build_ready`,
  `apkUrl` — actually a `.zip` URL now, needs manual unzip before
  installing). **Do not** put the link in `android.fcmOptions.link` —
  that field only exists on `WebpushConfig`, using it on `AndroidConfig`
  causes a 400. `main.dart`'s `_handleNotificationTap` reads
  `message.data['type'] == 'build_ready'` and opens `apkUrl` via
  `url_launcher`.
- Only the account matching `_devEmail` in `main.dart`
  (`abhishek2005.siva@gmail.com`) auto-subscribes to `dev_builds` — same
  literal email reused as the Wildcards `_kGranterEmail` gate.
- Workflow needs `permissions: contents: write` for the release step.

### Together / Memories / Settings visual overhaul (early pass)
Redesigned to match reference screenshots the user provided, one at a
time, before the Journal/Letters/Room work:
- **Together ("Fun") screen**: data-driven "Tonight's Pick" hero card,
  sectioned `_FeatureCard` grid (2-up, gradient per section), a
  `_CoinTossDialog` with a real 3D-flip `Transform`+`AnimationController`
  (`..setEntry(3,2,0.00x)..rotateY(spin)` — the same flip technique later
  reused for the Wildcards card-reveal dialog).
- **Memories wall**: `CustomScrollView` + slivers so the whole page is
  one continuous scroll with a `SliverPersistentHeaderDelegate`-pinned
  filter row (Google Photos/Apple Photos style) — this was a specific,
  explicit ask (no "multiple independent scroll views"). Collection cards
  show a real random 2×2 collage of that collection's own photos (seeded
  `math.Random`, stable per collection, not literally random every
  rebuild).
- **You & Me (settings)**: Love Dial card with a dotted SVG-style
  connector (`_DottedLink`/`_DotsPainter`), Connection Alerts toggle
  wired to a real `notifications_enabled` SharedPreferences pref +
  FCM topic subscribe/unsubscribe (not a fake switch).
- Recurring principle applied throughout: no fabricated badges/labels —
  e.g. no "Selfies" filter (can't actually detect selfies), Trips/Dates
  filters are honest keyword-heuristic matches on titles, described as
  such, not claimed as real tagging.

### Journal rewrite (bookshelf metaphor)
- Went through **two** rewrites. First pass had a fixed background image
  with 3 hardcoded shelf y-positions (`_kShelfFractions`) — bug: a 4th+
  shelf's books had nowhere to go and silently became horizontally
  scrollable overflow on shelf 3 forever. Fixed by dropping the fixed
  image, computing shelf capacity dynamically from available width,
  grouping entries by year, rendering a scrollable list of `_ShelfRow`s
  each with its own painted `_WoodPlank`.
  - Later, a *real* candlelit-bookshelf photo the user supplied
    (`assets/images/journal_bookshelf_bg.png`) replaced the flat brown
    background — used as a fixed, non-scrolling full-screen backdrop;
    the procedurally-drawn shelves/planks/spines scroll on top of it.
    Pixel-perfect alignment with the photo's own painted shelves was
    explicitly *not* attempted beyond the first screenful — flagged as a
    known, accepted limitation.
- Second pass unified journal entries and letters onto the same shelf via
  a generic `_ShelfBook` shape, added real filter chips (Letters/Photos/
  Trips/Dates/Random — Random uses a reroll-able seed, not true random
  per rebuild), a `_StatsPlaque` with real counts, animated `_BookSpine`
  (lift-on-press, category icon, bookmark ribbon), and a
  "Memory of the Day" card (stable per-day pick of a real captioned
  memory, not fabricated).
- **Recipes reuses this exact visual system** (same background image,
  same spine/plank/stats/filter-chip widgets, re-implemented in its own
  file since Dart privacy means the Journal's widgets can't be imported
  cross-file) — grouped by meal category instead of year.

### Letters (envelope hero + polish passes)
- Hero envelope illustration, subject field with an "Inspire me" random-
  occasion button (explicitly *not* branded "AI" — it's a static curated
  list), per-unlock-option tinted `_UnlockChip`s (Tomorrow/Next Week/Open
  When/birthdays/anniversary/custom date, each a fixed accent color),
  parchment-styled rich-text body editor.
- Follow-up polish pass added floating sparkles by the title, illustrated
  per-card background motifs (sunrise/wave/clouds/clock via a small
  `CustomPainter`), a paperclip on the parchment editor, and a
  glassmorphism subject field (`BackdropFilter` + translucent gradient) —
  all explicitly scoped as "vector/illustrated," not photoreal, since
  there is no image-generation tool available.
- **Bug fixed once, don't reintroduce**: a multi-block rich-text letter
  (containing an image/heading/etc., not just plain text) rendered
  invisible text in the cream-colored preview dialog. Root cause:
  wrapping `RichContentViewer`/`RichContentEditor` in a `Theme(...)`
  override does *nothing* for `Text` widgets that don't set their own
  color — `Text` inherits from the ambient `DefaultTextStyle`, not from
  `Theme.of(context).textTheme` unless something re-establishes
  `DefaultTextStyle` (a bare `Theme` widget doesn't). Fix was
  `DefaultTextStyle.merge(style: TextStyle(color: ...))` around the
  viewer/editor, and threading an explicit `textColor`/`hintColor` into
  `_LinkBlockEditor` specifically (the one block type with hardcoded
  white text).
- Large-photo-upload bug fixed once: `RichContentEditor`'s image picker
  used `picker.pickMedia()` with **no** `imageQuality`/`maxWidth` caps,
  unlike every other upload path in the app (avatar, photo booth,
  memories all compress first) — a full-res modern camera photo could
  exceed Cloudinary's upload limit. Fixed by adding
  `maxWidth: 1920, maxHeight: 1920, imageQuality: 85` to that one
  `pickMedia()` call.

### Book Wishlist
- Redesigned around a supplied reference image: header with split-color
  title, two real-count stat cards, a "wood plank" tab selector
  (Wishlist/Read Together), and an "open book" parchment panel holding
  the actual list (no card-per-item chrome) with a page-edge sliver and a
  ribbon tail. Book covers are colored-spine placeholders with the
  title's first letter (deterministic color from a hash), or a real
  cover image if the book has one.
- A background image the user supplied
  (`assets/images/book_wishlist_bg.png`) is used as a fixed backdrop the
  same way the Journal's bookshelf photo is.

### Chat feature additions (pulled from a separate remote session)
- Message editing, reply-with-preview, view counts, a notifications
  inbox (bell icon on `/room` + `/notifications` screen), Destinations
  search improvements (location-biased, opens on current location, "all
  pins" list), Memories swipe-up detail sheet (location/date/time/view
  count). A low-contrast reply-preview text color was fixed at some
  point (check git log for exact commit if it resurfaces).

### Wildcards and Recipes (this session, in order)
- Wildcards: user's own real relationship tradition ("special cards" for
  cheering up / apologizing) turned into a feature. Confirmed design
  choices via direct questions before building: card rank/suit is pure
  cosmetic flavor (not mechanic-gating), only one account can *grant* a
  card directly (see gating note above), the other partner can request
  one that needs approval. Ships with a curated favor-text suggestion
  list (mirrors the user's own example phrasing) plus free-text entry.
- Recipes: explicitly asked to reuse "the same UI design like Journal" —
  built as a near-complete visual clone of the bookshelf system
  (necessarily a separate implementation file, see above) with a
  category-appropriate structured editor instead of the journal's
  free-form rich text.

### The room: isometric → real 3D (biggest single pivot this session)
See the dedicated "shared 3D room" section above for the full technical
detail. Order of events, for context: (1) built a from-scratch isometric
CustomPainter room with a large (~222 item) hand-drawn vector catalog
across many categories per the user's own wishlist; (2) user said the
objects "look very very basic" and asked to import real assets from a
site of their choosing — researched Kenney.nl, found the "Furniture Kit"
pack's `Isometric/` folder has genuine pre-rendered CC0 PNG sprites (not
the 3D-model-only pack it first looked like), integrated ~34 of them as
real `Image.asset` billboards layered over the vector fallback for
items with no good sprite match; (3) added `InteractiveViewer` pinch-
zoom/pan and a first pass of app-wide "cute jump-burst" tap animations
(see `cuteStickers` above); (4) user then asked to throw the *entire*
isometric approach away for genuine 3D — rebuilt as the Three.js/WebView
room described above, "basic furniture only." Each of these was its own
approved decision point, not scope creep — don't be surprised the git
history shows a feature being built twice in different technologies.

### Memory-system note
This project's Claude Code long-term memory store
(`~/.claude/projects/.../memory/`) was **empty** as of this dump — no
memory entries had been saved during this session. This `CLAUDE.md` is
the intended substitute: durable, repo-tracked context available to any
agent (local or cloud) that opens this repository, rather than
personal cross-session recall tied to one harness/user pairing.
