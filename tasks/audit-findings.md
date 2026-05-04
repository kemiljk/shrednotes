# Shrednotes Audit Findings (Interim — Wave 7)

Status: 15 of 16 static auditors complete. Energy auditor still running. Wave 6 (build/runtime via axe) and Wave 8 (visual polish) not yet started.

App version: 2026.1, iOS 26.0 deployment target, Swift 5, ~62 Swift files, SwiftUI + SwiftData.

---

## P0 — CRITICAL (ship blockers, crashes, data loss, App Store)

| # | Finding | File:Line | Source | Fix |
|---|---|---|---|---|
| P0-1 | **Privacy Manifest missing** (`PrivacyInfo.xcprivacy`). UserDefaults Required Reason API used. App Store will reject the build. | new file `Shrednotes/PrivacyInfo.xcprivacy` | security | Create manifest with `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` |
| P0-2 | **No `VersionedSchema` / `SchemaMigrationPlan`** despite schema having evolved (`tip`, `wantToLearn`, `wantToLearnDate`, `workoutUUID`, `consistency`, etc. added over time). Existing-user crash / silent migration risk. | [Models/SharedModelContainer.swift:16](Shrednotes/Models/SharedModelContainer.swift) | swiftdata | Declare `SchemaV1`/`SchemaV2`, pass `migrationPlan:` to `ModelContainer` |
| P0-3 | **`Schema([...])` missing 6 model types**: `Note`, `Prerequisite`, `DependentTricks`, `Entry`, `MediaItem`, `ComboElement`. Once a VersionedSchema is added with the same omission, those tables get silently dropped. | [Models/SharedModelContainer.swift:16](Shrednotes/Models/SharedModelContainer.swift) | swiftdata | Add all 9 model classes to Schema array |
| P0-4 | **`Trick.init(from:)` force-decodes optional fields** (`wantToLearnDate`, `type`). Decoding any older trick payload (e.g. via `decodeTrick` in MainView's `onOpenURL`) crashes. | [Models/Model.swift:163,170](Shrednotes/Models/Model.swift) | swiftdata | Use `decodeIfPresent` for optional fields |
| P0-5 | **Force-unwraps in SearchView**: `$0.title!` and `combo.name!`. Sessions from Share extension may have nil titles → crash mid-search. | [Views/SearchView.swift:47,57](Shrednotes/Views/SearchView.swift) | nav | `($0.title ?? "").localizedCaseInsensitiveContains(...)` |
| P0-6 | **CloudKit schema divergence**: main container has no `cloudKitDatabase:` but `skateSessionExtensionModelContainer` declares `.automatic`. Two containers share the same SQLite via App Group with mismatched CK config → unreliable sync of sessions created in main app. | [Models/SharedModelContainer.swift:22 vs 65](Shrednotes/Models/SharedModelContainer.swift) | icloud, swiftdata | Unify CloudKit config across both containers (preferably both `.automatic`) |
| P0-7 | **iCloud account availability not checked** before CloudKit-backed container access. Crash for users not signed into iCloud. | [Models/SharedModelContainer.swift:18,65](Shrednotes/Models/SharedModelContainer.swift), [Models/WatchModelContainer.swift:19](Shrednotes/Models/WatchModelContainer.swift) | icloud | Check `FileManager.default.ubiquityIdentityToken` before enabling CK; fall back to local-only |
| P0-8 | **App Intents (`OpenViewJournal`, `OpenPracticeTricks`, `OpenSKATEGame`) trigger fullScreenCovers over Home tab, never switching tabs.** Tab selection state and NavigationModel are disconnected. | [Widget/AppIntents.swift:58-112](Widget/AppIntents.swift), [Views/MainView.swift:193-203](Shrednotes/Views/MainView.swift), [ShrednoteApp.swift:20](Shrednotes/ShrednoteApp.swift) | nav | Move `selectedTab` into `NavigationModel`; bind `TabView(selection:)` to it; have intents set `selectedTab` |
| P0-9 | **`isSuggestingTricks` never reset on early-exit/error path** in trick-suggestion AI flow. Permanently locks UI. | [Views/Journal/AddSessionView.swift:367-464](Shrednotes/Views/Journal/AddSessionView.swift), [Views/Journal/EditSessionView.swift:328-433](Shrednotes/Views/Journal/EditSessionView.swift) | foundation-models | `defer { isSuggestingTricks = false }` at top of function |
| P0-10 | **`UIImage(data: media.data)` decoded synchronously in `SessionCard.body`** (full-resolution, main thread, every render, every cell). Causes scroll jank. | [Views/Journal/SessionCard.swift:143-155, 178-208](Shrednotes/Views/Journal/SessionCard.swift) | swiftui-perf, swift-perf, layout | Decode in `.task`, store in `mediaState.imageCache`, never call `UIImage(data:)` in `body` |
| P0-11 | **`DateFormatter()` allocated inside computed properties / functions called every body pass** (3 sites in JournalView). | [Views/Journal/JournalView.swift:293-310, 308, 532-539](Shrednotes/Views/Journal/JournalView.swift) | swiftui-perf, swift-perf | Promote to `private static let monthYearFormatter` |
| P0-12 | **Redundant `.sorted(by:)` inside `ForEach` body** for sessions already sorted by `@Query`. O(n log n) per render. | [Views/Journal/JournalView.swift:104](Shrednotes/Views/Journal/JournalView.swift) | swiftui-perf | Delete `.sorted(...)` — Query already sorts |
| P0-13 | **Missing `@MainActor` on `SessionManager`** + `@Published` mutated from background `WCSession` delegate via `DispatchQueue.main.async`. Swift 6 hard error; `@Model` `SkateSession` sent across actor boundary (non-Sendable). | [Models/SessionManager.swift:5,38-48](Shrednotes/Models/SessionManager.swift) | concurrency | Add `@MainActor`, decode to `Codable & Sendable` DTO before crossing boundary, construct `@Model` on MainActor |
| P0-14 | **Missing `@MainActor` on `HealthKitManager`** with 6 sites mutating `@Published` from background HealthKit completions. Concurrent unsynchronized writes to `totalEnergyBurned` in `sumWorkoutData` (data race). | [Utilities/HealthKitManager.swift:12, 91-108](Shrednotes/Utilities/HealthKitManager.swift) | concurrency, swift-perf | Add `@MainActor`; replace `DispatchGroup` with `withTaskGroup` |
| P0-15 | **Missing `@MainActor` on `LocationManager`** + delegate callback mutations on background queue. | [Utilities/LocationManager.swift:11](Shrednotes/Utilities/LocationManager.swift) | concurrency | Add `@MainActor`, dispatch delegate work via `Task { @MainActor in }` |
| P0-16 | **Empty Home tab UX is unclear** — user confirmed "really weird with no data, unclear what to do." | [Views/MainView.swift](Shrednotes/Views/MainView.swift) (sections render with no data state) | user report | Wave 8 — design empty state with clear primary CTA ("Log your first session"). Validate against onboarding completion flag. |

---

## P1 — HIGH (UX regressions, perf cliffs, accessibility, modernization debt)

### Architecture
- **Massive view: `MainView.swift` (937 lines)** with URL decoding, recommendation scoring, widget reload side effects, 3× duplicated context-menu code. Untestable. → Extract `TrickRecommendationModel: @Observable`, `DeepLinkHandler`, shared `TrickContextMenu` ViewModifier. [Views/MainView.swift](Shrednotes/Views/MainView.swift)
- **`@StateObject` wrapping `SessionManager.shared`** creates two ownership paths and the env-injected instance may differ. [ShrednoteApp.swift:22](Shrednotes/ShrednoteApp.swift)
- **`DispatchQueue.main.async` wrapping already-on-main mutations** in MainView (5+ sites) causes one-frame flicker. [Views/MainView.swift:181-183, 494-496, 508-510, 636-641, 858-861](Shrednotes/Views/MainView.swift)
- **`MediaState` allocated as `@StateObject` in JournalView and TrickDetailView**, parallel to root-level injected one. Caches never shared. [Views/Journal/JournalView.swift:19](Shrednotes/Views/Journal/JournalView.swift), [Views/Tricks/TrickDetailView.swift:23](Shrednotes/Views/Tricks/TrickDetailView.swift)
- **`@Query` declared on App struct but unused in body** — keeps active SwiftData subscription for app lifetime. [ShrednoteApp.swift:33](Shrednotes/ShrednoteApp.swift)
- **`NavigationStack.id(inProgressTricksCount)`** — destroys/rebuilds entire navigation hierarchy on count change, popping any pushed view. [Views/MainView.swift:164](Shrednotes/Views/MainView.swift)

### Modernization (iOS 26 ready, no fallback needed)
- **`ObservableObject` → `@Observable`** for `SessionManager`, `HealthKitManager`, `LocationManager`, `LearnedTrickManager`. ~7 file edits. (Combined with P0 @MainActor fixes.)
- **`Trick: ObservableObject`** redundant on `@Model` — produces double-invalidation. Remove from Trick, Note, Prerequisite, DependentTricks. [Models/Model.swift:90](Shrednotes/Models/Model.swift)
- **9 deprecated `onChange(of:) { newValue }`** → new two-arg form. MainView, SettingsView.
- **`NavigationView` in Share Extension** → `NavigationStack`. [Views/Journal/Photos Share Extension/ShareView.swift:13](Shrednotes/Views/Journal/Photos%20Share%20Extension/ShareView.swift)

### Foundation Models
- **`AIModelAvailability.withAvailability` collapses all GenerationError → `.unavailable`**, hiding `.exceededContextWindowSize` and `.guardrailViolation`. [Utilities/AIModelAvailability.swift:65-71](Shrednotes/Utilities/AIModelAvailability.swift) → re-throw `LanguageModelSession.GenerationError`.
- **No specific catches for `.exceededContextWindowSize` / `.guardrailViolation`** at three call sites — generic message hides actionable causes.
- **New `LanguageModelSession` per tap** in TrickDetailView.regenerate, AddSessionView, EditSessionView — accumulates streaming buffers. Hoist to `@State`.
- **No streaming** for multi-sentence summaries/tips (`respond(to:)` instead of `streamResponse(to:)`).
- **No `@Generable` for trick extraction** — fragile CSV parsing of free-text response.
- **Prompt injection risk**: raw user note interpolated without delimiters. [Views/Journal/AddSessionView.swift:391](Shrednotes/Views/Journal/AddSessionView.swift), [EditSessionView.swift:352](Shrednotes/Views/Journal/EditSessionView.swift)

### Data
- **No `try? modelContext.save()` after trick mutations** in MainView context menus (~10 sites). Crash window between mutation and autosave loses data.
- **`cleanUpTricks` deduplication** picks `.first` of duplicates, drops sibling's relationship data (notes, sessions, entries) without merging. Risk: silent data loss on iCloud-synced reinstall. [Models/SharedModelContainer.swift:87-101](Shrednotes/Models/SharedModelContainer.swift)
- **`trickDatabaseVersion` in `@AppStorage`** doesn't survive iCloud restore → user reprompted to "add" tricks they already have. [ShrednoteApp.swift:18](Shrednotes/ShrednoteApp.swift), [Models/SharedModelContainer.swift:14](Shrednotes/Models/SharedModelContainer.swift)
- **Most `@Relationship` fields lack explicit `deleteRule`** — orphaned references after deletes; CloudKit "missing record" sync loops. [Models/Model.swift:304-305](Shrednotes/Models/Model.swift)

### Storage
- **`MediaItem.data: Data`** stored directly in SwiftData → backed up to iCloud → eats user's 5GB free quota. 100 photos × 2MB ≈ 40% of free quota. [Models/Model.swift:231-270](Shrednotes/Models/Model.swift) → store `assetIdentifier` for Photos library media; only blob captured/imported video to Caches with `isExcludedFromBackup`.
- **Video files written to `NSTemporaryDirectory()`** without protection or backup exclusion; iOS purges tmp under storage pressure. [Utilities/TempFileCleanup.swift:6-30](Shrednotes/Utilities/TempFileCleanup.swift), [Utilities/Utils.swift:141-152](Shrednotes/Utilities/Utils.swift) → use Caches + `isExcludedFromBackup`.

### Performance (HIGH)
- **`@Query(sort: ...)` for sessions in every `TrickRow`** — 200+ active queries; `calculateStreak` O(sessions×tricks) per body. [Views/Tricks/TrickRow.swift:17-21](Shrednotes/Views/Tricks/TrickRow.swift) → hoist sessions query to parent, pass via parameter, cache streak.
- **`MediaState` is `ObservableObject` (not `@Observable`)** → every thumbnail load invalidates ALL SessionCards. [Models/Model.swift:273](Shrednotes/Models/Model.swift) → migrate to `@Observable` for fine-grained tracking.
- **Reverse geocoding fired on every SessionCard.onAppear** without caching/persistence. [Views/Journal/SessionCard.swift:231-255](Shrednotes/Views/Journal/SessionCard.swift) → persist resolved name to `session.location?.name` first time.
- **`saveVideoToTemporaryDirectory` writes raw `Data` (50MB+) synchronously in `loadThumbnail`**, called from `.onAppear` on the main thread. [Views/Journal/SessionCard.swift:217](Shrednotes/Views/Journal/SessionCard.swift) → `Task.detached(priority: .utility)`.
- **`filteredTricks` recomputes `searchText.lowercased().split` per trick** in filter closure (230× per keystroke). [Views/Tricks/FullTrickListView.swift:31](Shrednotes/Views/Tricks/FullTrickListView.swift) → hoist outside the closure.
- **`tricks.filter { $0.isLearned }.count` runs 10× per body** in DisclosureGroup label. [Views/Tricks/FullTrickListView.swift:222,307](Shrednotes/Views/Tricks/FullTrickListView.swift) → cache `learnedCount`.
- **`generateSummary()` fires on every `sessions` change without debounce** → N concurrent inference tasks during sync. [Views/Journal/JournalView.swift:147-158](Shrednotes/Views/Journal/JournalView.swift)

### Memory
- **PHAsset `requestImage` request IDs discarded** → no cancel on disappear, in-flight requests fire against stale state. [Utilities/PhotosHelper.swift:34-42](Shrednotes/Utilities/PhotosHelper.swift), [Views/Journal/AddSessionView.swift:882](Shrednotes/Views/Journal/AddSessionView.swift)
- **`preloadedPlayers: [UUID: AVPlayer]` never cleared** in SessionDetailView/TrickDetailView. AVPlayer holds decoded video buffers. [Views/Journal/SessionDetailView.swift:26](Shrednotes/Views/Journal/SessionDetailView.swift), [Views/Tricks/TrickDetailView.swift:24](Shrednotes/Views/Tricks/TrickDetailView.swift) → clear in `.onDisappear`.
- **HealthKit completion `[weak self]` on a singleton** — atomic overhead with no benefit. [Utilities/HealthKitManager.swift:59,80,138](Shrednotes/Utilities/HealthKitManager.swift) → `[unowned self]` or remove.
- **Duplicate `HealthKitManager` instances**: `static let shared` AND `@StateObject` allocation in App. [ShrednoteApp.swift:23](Shrednotes/ShrednoteApp.swift)

### Layout / iPad
- **`GeometryReader` inside `List` section** in TrickDetailView/EditSessionView mediaSection — unpredictable size on iPad. [Views/Tricks/TrickDetailView.swift:476-490](Shrednotes/Views/Tricks/TrickDetailView.swift), [Views/Journal/EditSessionView.swift:522-536](Shrednotes/Views/Journal/EditSessionView.swift) → `LazyVGrid` with `.flexible()` columns, `containerRelativeFrame`.
- **Fixed 300pt hero heights** don't scale with Dynamic Type. [Views/Journal/SessionDetailView.swift:49,423,436,477](Shrednotes/Views/Journal/SessionDetailView.swift)
- **No `horizontalSizeClass` adaptation** — single-column on iPad regular wastes space.
- **Hardcoded `.padding(.top, 48)` for safe area** in MediaGalleryView dismiss button — wrong on Dynamic Island, iPad split view. [Views/MediaGalleryView.swift:56](Shrednotes/Views/MediaGalleryView.swift)
- **`OnboardingView` switch on `currentStep`** loses identity per step — scroll/animation state destroyed on step change. [Views/Onboarding/OnboardingView.swift:47-62](Shrednotes/Views/Onboarding/OnboardingView.swift) → `TabView(.page)` or explicit `.id()`.

### Liquid Glass / iOS 26
- **MainView 3 section cards** (recommendation / inProgress / basedOnTricksYouKnow) use manual gradient + opacity colorScheme branching. → `.glassBackgroundEffect(in: .rect(cornerRadius: 28))` + `.tint(.indigo.opacity(0.15))`. [Views/MainView.swift:576-580, 808-813, 917-930](Shrednotes/Views/MainView.swift)
- **SessionCard background uses `.ultraThinMaterial`** instead of glass. [Views/Journal/SessionCard.swift:141-158](Shrednotes/Views/Journal/SessionCard.swift)
- **TrickPracticeView feedback overlays** use `.ultraThinMaterial`/`.thinMaterial`. → `.glassBackgroundEffect`. [Views/Tricks/TrickPracticeView.swift:147-178](Shrednotes/Views/Tricks/TrickPracticeView.swift)
- **MainView and JournalView toolbar primary action** lacks `.borderedProminent` for iOS 26 prominent treatment.
- **FullTrickListView filter chips** manual selected/unselected branching → `.glassEffect(.regular.tint(.indigo))`.
- **`GradientButton`** flat opaque gradient capsule competes with chrome. → glass variant with tint.

### Accessibility (CRITICAL for App Store)
- **Icon-only buttons missing `.accessibilityLabel`**: GradientButton (settings/plus), JournalView filter/insights/add, SettingsView close, TrickDetailView ellipsis (~8 sites total). VoiceOver-blocking.
- **`ConsistencyRatingView` tap gestures** lack `.accessibilityElement` / traits — VoiceOver can't activate.
- **Form fields** in AddSessionView lack explicit `accessibilityLabel`.
- **Touch target < 44pt**: TrickDetailView ellipsis menu `frame(width: 32, height: 32)`. [Views/Tricks/TrickDetailView.swift:116](Shrednotes/Views/Tricks/TrickDetailView.swift)
- **No Reduce Motion guards** on spring animations / scroll transitions (5+ sites).
- **No `@ScaledMetric`** for fixed spacing in heatmap, legend boxes (10pt color swatches don't scale).

---

## P2 — MEDIUM (polish, consistency, maintainability)

- **Dead code**: `MainView.latestSkateView` defined but never called. [Views/MainView.swift:583-594](Shrednotes/Views/MainView.swift)
- **Hardcoded "5 Days" / "8 Weeks" streak strings** in InsightDetailView. [Views/Journal/InsightDetailView.swift:109-115](Shrednotes/Views/Journal/InsightDetailView.swift)
- **`SKATEGameView` auto-selects trick on every search-text change** — sheet dismisses before user finishes typing. [Views/Game/SKATEGameView.swift:785-791](Shrednotes/Views/Game/SKATEGameView.swift)
- **Duplicate iOS 26/<26 `TabView` branches in App** that are essentially identical (deployment target is 26, fallback unreachable). [ShrednoteApp.swift](Shrednotes/ShrednoteApp.swift) → delete fallback branch.
- **`silent error swallow`** on `try? JSONDecoder()...decode(Set<TrickType>.self, ...)` — visible-trick-types data loss invisible to user. [ShrednoteApp.swift:47](Shrednotes/ShrednoteApp.swift)
- **`SessionReference` failable init silently substitutes new UUID** when source `SkateSession.id` is nil. [Models/Model.swift:81-87](Shrednotes/Models/Model.swift)
- **No date encoding strategy** explicitly set on JSONEncoder/Decoder anywhere — timezone bugs.
- **`IdentifiableLocation.hash(into:)` combines 4 fields** including String, despite UUID id being unique. [Models/Model.swift:450-455](Shrednotes/Models/Model.swift)
- **Hardcoded `1pt` selection stroke** on app icon picker — hard to see. [Views/SettingsView.swift:88](Shrednotes/Views/SettingsView.swift)
- **No `NavigationPath`/`@SceneStorage`** for navigation state restoration across all 4 NavigationStacks.
- **`.onOpenURL` only on MainView** — fires only when Home tab is visible. Should be at WindowGroup. [Views/MainView.swift:331-341](Shrednotes/Views/MainView.swift)
- **`AddJournalEntryIntent` posts `NotificationCenter` notification** that nothing observes — dead code. [Widget/AppIntents.swift:26-38](Widget/AppIntents.swift)
- **No `.tabViewStyle(.sidebarAdaptable)`** for iPad sidebar adoption. [ShrednoteApp.swift:70-117](Shrednotes/ShrednoteApp.swift)
- **`SettingsView` cancel uses `xmark`** instead of `Button(role: .cancel)` for system glass treatment. [Views/SettingsView.swift:246-252](Shrednotes/Views/SettingsView.swift)
- **`HapticManager.impact()` allocates `UIImpactFeedbackGenerator` per call** instead of caching. [Utilities/Utils.swift:469-472](Shrednotes/Utilities/Utils.swift)
- **`generateTricks()` allocates ~230 `Trick`/`Prerequisite` objects synchronously on main thread** at first launch. [Models/Tricks.swift:11](Shrednotes/Models/Tricks.swift) → wrap in `Task.detached`, gate with UserDefaults flag.
- **`sharedModelContainer` initialization synchronously on MainActor** — blocks launch with SQLite introspection.
- **Container CK error handling absent** (`quotaExceeded`, `networkUnavailable`, `notAuthenticated`).
- **Watch ↔ Phone sync no conflict resolution** — silent loss of one side's edits.
- **`MainView.activeSheet` enum + multiple booleans** for sheet routing — redundant state.
- **`InsightDetailView` `sessionsThisWeek/Month/Year`** triple filter pass over all sessions per body.

---

## P3 — LOW / Build hygiene

- **Build settings**: missing `SWIFT_COMPILATION_MODE = singlefile` in Debug (forces full recompile every build). 40-60% incremental Debug speedup. [project.pbxproj](Shrednotes.xcodeproj/project.pbxproj)
- **`ONLY_ACTIVE_ARCH` missing in extension Debug configs** → 20-30% per-extension compile waste.
- **`ENABLE_PREVIEWS = YES` in Release** for Shrednotes + Watch targets → dead overhead in shipped binary.
- **No `OTHER_SWIFT_FLAGS` type-checking diagnostics** — invisible slow expressions in 4 view files >800 lines each.
- **`FUSE_BUILD_SCRIPT_PHASES` not set** at project level.
- **No tests** — zero test targets in pbxproj. SwiftData migrations, Share extension hand-off, HealthKit permission flow uncovered. → extract `ShrednoteCore` Swift Package, add unit + integration tests.
- **CoreImage imported in 3 places** — minor module loading overhead.
- **Generic `print()` debug logs** in BackgroundNotificationsClass — should be `os.Logger` (and excluded from Release).
- **`static let shared = SkateboardTrickApp()` in App struct** — never safe; SwiftUI controls App lifecycle.
- **`@AppStorage` keys read from multiple files** without typed key constants.

---

### Energy

- **`kCLLocationAccuracyBest` for one-shot skatepark pin** — wakes GPS until sub-5m fix. Should be `kCLLocationAccuracyHundredMeters`. [Utilities/LocationManager.swift:20](Shrednotes/Utilities/LocationManager.swift)
- **4 separate `LocationManager` instances** (AddSessionView, LocationPickerView, SettingsView, OnboardingView) — AddSession + child LocationPicker fire two simultaneous GPS queries on the same screen. → inject one through environment.
- **HealthKit uses `HKSampleQuery` polling on every `onAppear` and `onChange(of: date)`** instead of using the already-declared (but unused) `workoutObserverQuery: HKAnchoredObjectQuery?`. 15-40% drain/hr while active. [Utilities/HealthKitManager.swift:28, 56-88](Shrednotes/Utilities/HealthKitManager.swift), [Views/Journal/AddSessionView.swift:308-321](Shrednotes/Views/Journal/AddSessionView.swift), [Views/Journal/SessionDetailView.swift:241-242](Shrednotes/Views/Journal/SessionDetailView.swift)
- **`AnimatedGradient` and `PulseEffect` use `repeatForever` with no `onDisappear` stop** — animations continue while view is offscreen but in hierarchy. [Utilities/Utils.swift:728, 363-377](Shrednotes/Utilities/Utils.swift)
- **`UIBackgroundModes` declares `fetch`** but no `BGTaskScheduler.register(...)` exists anywhere → wasted background CPU grants. [Info.plist:34-38](Shrednotes/Info.plist)
- **`SessionDetailView` writes full video `Data` to temp file on every `onAppear`** — duplicate copies accumulate. → cache temp URL by `mediaItem.id`.
- **`checkSkateInactivity` runs on every `.active` scene phase**. Throttle to once per 24h via UserDefaults timestamp.
- **`WidgetCenter.shared.reloadAllTimelines()` called from 6+ MainView sites** — debounce or call only on data change.

---

## Wave 8 — Visual Polish Findings (live screenshot review on iPhone 17 Pro Max iOS 26)

13 screenshots saved to `tasks/audit-screenshots/`.

### V0 — CRITICAL (user-flagged + observed)

**V0-1 — Empty Home tab UX is confusing** (user-flagged) — see [01-home-empty-state.jpg](tasks/audit-screenshots/01-home-empty-state.jpg) and [09-home-empty-dark.jpg](tasks/audit-screenshots/09-home-empty-dark.jpg)

The empty Home tab shows only a "BASED ON TRICKS YOU KNOW" card with three generic Basic tricks (Kickturn, Ollie, Tic-Tac), each with hollow circles and 5-cell empty progress bars. Below: ~430pt of dead whitespace ending at the tab bar. There is **no welcome message, no orientation, no primary CTA**. The primary entry point ("Add Session") is buried behind a tiny `+` button in the top-right that opens a 3-item Menu (Add Session / Add Combo / Add Trick). A new user has no idea what to do.

Compare to the **Journal tab empty state** ([02-journal-empty-state.jpg](tasks/audit-screenshots/02-journal-empty-state.jpg)) — the gold standard: hero icon, title "No Journal Entries", subtitle "Add a skate session to get started.", clear primary purple "Add Session" CTA. Home should adopt this same pattern when there are zero sessions.

Fix:
- When `sessions.isEmpty && tricks.allSatisfy({ !$0.isLearned && !$0.isLearning })`, render a Home empty state mirroring Journal: hero icon + "Welcome to Shrednotes" + "Log your first session to start tracking your progress." + primary `.borderedProminent` `Button("Add Session")`.
- Optionally retain the "Based on Tricks You Know" card but secondary, with a clearer subtitle ("Try one of these basics to get started"), so it reads as guidance rather than placeholder data.
- The hollow circles on each trick row are unlabelled — VoiceOver hears nothing useful, sighted users don't know they're tappable. Either label them ("Mark as learning") or remove until the user has marked at least one trick.

**V0-2 — Settings gear button has `AXLabel: "gearshape"`** (the SF Symbol *name*, not a human label). VoiceOver reads "gearshape, button". Confirmed via `axe describe-ui --point 30,84`. Toolbar in [Views/MainView.swift](Shrednotes/Views/MainView.swift) → `.accessibilityLabel("Settings")`.

**V0-3 — Trick Detail nav bar transparency under scroll** ([13-trick-detail-scrolled-dark.jpg](tasks/audit-screenshots/13-trick-detail-scrolled-dark.jpg))

Scrolled AI-tip content overlaps the nav bar title (the word "Tips" bleeds through the same Y range as the toolbar). Either the toolbar is missing a background (`.toolbarBackground(.visible, for: .navigationBar)` or `.glassEffect`) or the scroll content lacks proper top inset. iOS 26 should auto-apply Liquid Glass scrim; investigate in [Views/Tricks/TrickDetailView.swift](Shrednotes/Views/Tricks/TrickDetailView.swift).

### V1 — HIGH (visible UX issues)

- **Search tab pre-populates "Recent Tricks" with 5 tricks** ([05-search.jpg](tasks/audit-screenshots/05-search.jpg)) for a brand-new user who never opened a trick. Either showing wantToLearn-flagged seed tricks as "recent" (misleading), or the recents query isn't filtered to actually-visited tricks. → audit "Recent" query, show empty-state messaging when no real recents.
- **"Recent Sessions" / "Recent Combos" empty headers** show with no body and no empty-state — they look broken. → hide section when empty or show placeholder.
- **`+` button on Home opens a `Menu`** ([07-home-add-menu.jpg](tasks/audit-screenshots/07-home-add-menu.jpg)) — primary action should be a direct `.borderedProminent` `Button("Add Session")` with secondary entries moved to overflow or contextual locations (Add Combo on Journal toolbar, Add Trick on Tricks toolbar).
- **Tricks tab filter chips clip "Footp..." off the right edge** ([03-tricks-list.jpg](tasks/audit-screenshots/03-tricks-list.jpg)). Horizontal `ScrollView` should hint scrollability with a fade gradient or fully expose chips. [Views/Tricks/FullTrickListView.swift:94-128](Shrednotes/Views/Tricks/FullTrickListView.swift)
- **Add Session "Feeling" pills clip "Hyp..."** ([08-add-session-sheet.jpg](tasks/audit-screenshots/08-add-session-sheet.jpg)) — same root cause.
- **Add Session confirm button is icon-only checkmark** in top-right. Should be a labelled button (`Save`/`Done`) or use `Button(role: .confirm)` with text.
- **Trick row "Basic" type label appears beneath name in tiny gray text** then a 5-segment progress bar with 1 segment filled. The progress semantics aren't conveyed — what does "1 of 5" mean? Practice consistency? Add accessibility hints + a sighted-user legend somewhere.

### V2 — MEDIUM (polish / consistency)

- **Trick list type headers are bright purple ALL CAPS** ("BASIC 0/21", "AIR 0/48"). Stylistically unique to this view; rest of the app uses softer typography. → `.font(.subheadline.bold()).foregroundStyle(.secondary)` for consistency, or own the styling globally.
- **Tricks footer cards "226 tricks" / "0 learned"** stuck to the bottom edge above the tab bar without padding/separation.
- **Home card has subtle pink/purple gradient** that's only visible in dark mode ([09-home-empty-dark.jpg](tasks/audit-screenshots/09-home-empty-dark.jpg)) — barely perceptible in light. Prime candidate for `.glassBackgroundEffect(.regular.tint(.indigo.opacity(0.12)))` per liquid-glass auditor.
- **`Button("Randomize & Start")` in S.K.A.T.E** uses same purple capsule as Add Session — consistency is good, but consider varying for hierarchy. Player-row `−` buttons need accessibility labels.
- **Search tab uses iOS 26 search-role tab** correctly but the input morph has a separate skater-icon pill on the left — slightly busy.
- **Settings Customisation toggles** ([06-settings.jpg](tasks/audit-screenshots/06-settings.jpg)) icons feel inconsistent with the rest of the app's settings styling.
- **Trick Detail "Consistency" buttons** look like a chart, not buttons. Low affordance + no a11y traits — covered by accessibility-auditor.
- **"Last 12 Weeks" heatmap legend** chips don't scale with Dynamic Type — fixed 10pt squares.

### V3 — LOW

- Empty progress-bar segments on Home recommendation card use thin gray underlines that look unfinished. If they represent "5 practice sessions to mastery", a tooltip/legend would help.
- Settings "CHANGE APP ICON" previews lack accessibility labels.
- Trick Detail back chevron has correct 44pt target.

---

## Outstanding

- ✅ All 16 static auditors complete.
- ✅ Wave 6 — App was already booted on iPhone 17 Pro Max; navigation across all 5 tabs + sheets succeeded with no visible runtime crashes. Did not rerun a clean build via XcodeBuildMCP since the running build was sufficient to drive screenshots — `mcp__XcodeBuildMCP__build_run_sim` with current defaults will revalidate before any sprint.
- ✅ Wave 8 — 13 screenshots covering all 5 tabs (light + dark for Home/Journal/Tricks), Settings, Add menu, Add Session sheet, Trick Detail (idle + scrolled).
- ✅ Wave 9 — Final implementation plan below.

## Recommended Implementation Order (post-audit)

**Sprint 1 — Stop the bleeding (P0 + user-flagged empty Home)**
1. `PrivacyInfo.xcprivacy` (App Store submission blocker)
2. SearchView force-unwraps (`title!`, `name!` → `?? ""`)
3. `Trick.init(from:)` `decode` → `decodeIfPresent` for `wantToLearnDate` + `type`
4. `defer { isSuggestingTricks = false }` in AddSessionView/EditSessionView
5. **Empty Home state redesign** (V0-1, user-flagged): hero icon + "Welcome to Shrednotes" + subtitle + primary `.borderedProminent` `Button("Add Session")`, gated on `sessions.isEmpty`. Mirror Journal's pattern.
6. Remove sync `UIImage(data:)` from `SessionCard.body`; promote `DateFormatter` instances to `private static let`; remove redundant `.sorted` in JournalView ForEach
7. Accessibility labels on all icon-only toolbar buttons (gear, +, filter, sparkles, ellipsis, xmark)

**Sprint 2 — Modernization + concurrency (P0/P1 combined)**
6. `@MainActor` + `@Observable` migration for SessionManager / HealthKitManager / LocationManager / LearnedTrickManager (single coordinated PR)
7. SwiftData VersionedSchema + complete Schema array + migration plan
8. CloudKit container unification + iCloud availability check
9. Data race fix in `sumWorkoutData` (withTaskGroup)

**Sprint 3 — Navigation + AI**
10. Move `selectedTab` into NavigationModel; bind TabView; consolidate App Intents
11. Move `.onOpenURL` to WindowGroup; adopt `NavigationPath`
12. Foundation Models error handling + session reuse + `@Generable` for trick extraction + prompt sanitization

**Sprint 4 — Performance + storage**
13. Hoist sessions query out of TrickRow; cache streak
14. `MediaState` → `@Observable`; remove duplicate allocations
15. MediaItem refactor — store `assetIdentifier` not blob; move video temp files to Caches with backup exclusion

**Sprint 5 — UI polish (Liquid Glass + a11y + remaining visual)**
17. Liquid Glass migration: 3 MainView section cards, SessionCard, TrickPracticeView overlays, FullTrickListView filter chips, toolbar prominent buttons
18. ConsistencyRatingView accessibility wrapper (`accessibilityElement` + traits + label); 44pt touch targets (TrickDetailView ellipsis menu); Reduce Motion guards on spring animations / scroll transitions
19. `@ScaledMetric` for heatmap and legend fixed sizes
20. Search "Recent Tricks/Sessions/Combos" empty-state + filter logic fix
21. Filter chips clipping (Tricks tab + Add Session feeling pills) — scroll/fade
22. Trick Detail nav bar background under scroll (V0-3) — `.toolbarBackground(.visible)` or proper inset
23. Add Session confirm button label ("Save"/"Done")
24. iPad adaptation (`.tabViewStyle(.sidebarAdaptable)` + `horizontalSizeClass` branches in detail/list views)

**Sprint 6 — Hygiene**
25. Build settings (SWIFT_COMPILATION_MODE, ONLY_ACTIVE_ARCH, ENABLE_PREVIEWS Release, FUSE_BUILD_SCRIPT_PHASES, type-checking flags)
26. Test target scaffolding + extract `ShrednoteCore` Swift Package + 20 high-ROI tests (SwiftData migrations, Share extension hand-off, HealthKit permission flow)
27. Dead code cleanup (`MainView.latestSkateView`, hardcoded "5 Days"/"8 Weeks", duplicate iOS 26 fallback TabView branch)
28. Deprecated `onChange` migration to two-arg form
29. Remove redundant `ObservableObject` from `@Model` types (Trick, Note, Prerequisite, DependentTricks)
30. Replace `print()` with `os.Logger`; gate debug logs in `#if DEBUG`
