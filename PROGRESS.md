# ScriptFlow — Progress Log

> Session-by-session development log.

---

## Session 1 — 2026-02-09

### What happened
- Explored the [Textream](https://github.com/f/textream) open-source macOS teleprompter codebase
- Analyzed the First Health Enrollment ACA Script 2.0 (9 pages, 8 phases, ~15 conditional branches, ~20 placeholders, ~12 coaching cues)
- Conducted product discovery interview covering: platform, interaction model, branching UX, team size, fill-in fields, coaching cues, color scheme, distribution, scroll mode, overlay style, script update frequency, hotkeys, app naming, phase indicators, practice mode, and compliance
- Wrote comprehensive PRD (PRD.md) capturing all decisions
- Initialized project documentation (CONTEXT.md, TASKS.md, PROGRESS.md, TEST_LOG.md, PLAN.md)

### Key Decisions Made
| Decision | Choice |
|----------|--------|
| Platform | Native macOS app (Swift/SwiftUI, forked from Textream) |
| App name | ScriptFlow |
| Primary scroll mode | Word tracking via on-device speech recognition |
| Overlay style | Floating window (draggable, always-on-top) |
| Script source | External Markdown file (hot-reloadable) |
| Branching UX | Show all branches, highlight relevant, dim irrelevant |
| Fill-in fields | Visual placeholders only (no data entry) |
| Coaching cues | Distinct visual style (red/coral italic) |
| Color scheme | Redesigned for teleprompter readability (dark bg, high contrast) |
| Phase tracking | Progress bar with clickable section labels |
| Controls | Global hotkeys (work when app not focused) |
| Practice mode | Included for agent training |
| Distribution | Direct DMG sharing |
| Compliance | On-device only, no concerns |

### Where we left off
PRD and all project documentation files created. Ready to begin **M1: Foundation** — forking Textream and setting up the ScriptFlow Xcode project.

### Next actions
1. Clone/fork the Textream repository
2. Set up the Xcode project and verify it builds
3. Begin rebranding to ScriptFlow

---

## Sessions 2–6 (not individually logged)

Significant development occurred across multiple sessions building out M1 and M2 features. The Textream codebase was forked, rebranded to ScriptFlow, and the full script engine was built including: ScriptParser, ScriptModel, MarqueeTextView, NotchOverlayController, ContentView, SpeechRecognizer integration, floating/pinned/follow-cursor overlay modes, classic/silence-paused/word-tracking listening modes, and settings.

---

## Session 7 — 2026-02-09

### What happened
- Implemented **Task #6: Script Rendering with Distinct Styles** — the overlay teleprompter now renders all word types with type-aware styling instead of plain white text
- **ScriptModel.swift**: Added `ScriptStyle` color constants, renamed `charOffset` → `speakableCharOffset` (-1 for non-speakable), added `totalSpeakableCharCount`, rewrote `taggedWords` builder (phase headers and branch labels as single words, only speakable words advance offset, normalized splitting with `\.isWhitespace`)
- **MarqueeTextView.swift** (major rewrite): New `WordItem` with `wordType`/`speakableCharOffset`/`prevSpeakableEnd`, `SpeechScrollView` accepts `taggedWords` + `totalSpeakableCharCount` + `highlightedSpeakableCharCount`, `WordFlowLayout` renders 5 types: speakable (white highlight-tracked), coaching (coral italic), placeholder (gold bold), branchLabel (cyan pill badge, own line), phaseHeader (centered divider with rules). `buildItems()` precomputes `prevSpeakableEnd`, `buildLines()` forces breaks around headers/branches, `activeDisplayWordIndex()` maps speakable→display space
- **NotchOverlayController.swift**: Updated `show()` signature to `show(taggedWords:speakableText:totalSpeakableCharCount:)`, both `NotchOverlayView` and `FloatingOverlayView` use tagged words, added `speakableCharsForWordProgress()` and `displayWordProgressForSpeakableOffset()` coordinate converters, tap guard for non-speakable words, progress bar uses speakable counts
- **ContentView.swift**: `run()` now computes and passes `taggedWords`, `speakableText`, `totalSpeakableCharCount`
- Build succeeded with zero errors
- Launched app for manual testing

### Key design decisions
- `prevSpeakableEnd` = `speakableCharOffset + word.count` (no +1) for correct trailing non-speakable handling
- Non-speakable "passed" check: `highlightedSpeakableCharCount >= prevSpeakableEnd && prevSpeakableEnd > 0`
- SpeechRecognizer.swift left **untouched** — still matches against speakable-only text
- Timer modes advance through all display words; coordinate converters handle the mapping

### Where we left off
Task #6 complete and building. App launched for manual testing. Need to verify all 5 word types render correctly in the overlay, speech tracking still works, and classic/timer modes scroll properly.

### Next actions
1. Manual QA of overlay rendering (all 5 word types visible and styled correctly)
2. Verify speech recognition tracking still works after the coordinate space changes
3. Test classic and silence-paused timer modes with the new display word indexing
4. Move on to remaining M2/M3 tasks (PhaseBarView, BranchManager, global hotkeys, etc.)

---

## Session 8 — 2026-02-09

### What happened
- Implemented **PhaseBarView** (PRD §4.2.1) — compact segmented progress bar at the top of the teleprompter overlay
- **NEW: `PhaseBarView.swift`** — Self-contained SwiftUI component. Segments proportionally sized by speakable content per phase. Three visual states: active (yellow bar, bright label), passed (white 30% fill, dimmed label), upcoming (white 10%, faint label). Phase titles extracted from `.phaseHeader` tagged words, auto-abbreviated for compact display. Tap any segment → `onPhaseSelected` callback. 28px height.
- **`ScriptModel.swift`**: Added `speakableCharsPerPhase` computed property — iterates `taggedWords`, sums `word.count + 1` per speakable word grouped by `phaseIndex`
- **`NotchOverlayController.swift`**: Threaded `speakableCharsPerPhase` parameter through `show()` → `showPinned()` / `showFloating()` / `showFollowCursor()`. Added property to both `NotchOverlayView` and `FloatingOverlayView`. Inserted `PhaseBarView` above `SpeechScrollView` in both `prompterView` and `floatingPrompterView`. Added `jumpToPhase()` method — uses `speechRecognizer.jumpTo(charOffset:)` for word tracking, sets `timerWordProgress` for timer modes.
- **`ContentView.swift`**: Computes `script.speakableCharsPerPhase` in `run()` and passes to overlay controller
- Build succeeded, app launched for manual testing

### Where we left off
PhaseBarView implemented and building. App launched for manual QA — need to verify:
1. Phase bar visible at top of overlay with 8 labeled segments
2. Current phase highlights as speech/timer progresses
3. Tapping a phase segment jumps to that phase
4. Works across all 3 listening modes and both pinned/floating overlays

### Next actions
1. Manual QA of PhaseBarView across overlay modes and listening modes
2. Continue M2/M3: BranchManager, global hotkeys, practice mode
3. Simplify SettingsView for ScriptFlow-specific options

---

## Session 9 — 2026-02-09

### What happened
Implemented **M5: Distribution** — full distribution pipeline for rollout to ~20 FHE agents.

#### Phase 1: Fixed build.sh (Textream → ScriptFlow)
- Replaced all Textream references with ScriptFlow (scheme, archives, app name, xcodeproj, volname, lipo path)
- Added version-stamped DMG naming: extracts `MARKETING_VERSION` from xcodebuild settings → `ScriptFlow-0.1.0.dmg`
- Added `codesign --force --deep --sign -` ad-hoc signing after lipo universal binary creation
- Added README.txt staging into DMG

#### Phase 2: Script Auto-Download (ScriptLoader.swift)
- **NEW: `ScriptLoader.swift`** — Remote-first script loading with 3-tier fallback:
  1. Fetch latest from GitHub Releases (`/releases/latest/download/aca-script.md`)
  2. Fall back to local cache (`~/Library/Caches/com.fhe.ScriptFlow/cached-aca-script.md`)
  3. Fall back to bundled `aca-script.md` resource
- `ScriptSource` enum (`.remote`, `.cached(Date)`, `.bundled`) with human-readable descriptions
- **Modified `ContentView.swift`**: `loadDefaultScript()` now async via `ScriptLoader.loadScript()`, shows source indicator (green checkmark for remote, orange info for cached/bundled), subtle warning for stale cache (>24h) or bundled-only

#### Phase 3: Sparkle Auto-Updates
- Added Sparkle 2.6+ as SPM dependency in `project.pbxproj`
- **Modified `ScriptFlowApp.swift`**: `import Sparkle`, `SPUStandardUpdaterController` in AppDelegate, "Check for Updates..." menu item after About
- **Modified `Info.plist`**: Added `SUFeedURL`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval` (daily)
- **NEW: `appcast.xml`** — Sparkle update feed template with placeholder GitHub Release URLs

#### Phase 4: First-Run Experience
- **NEW: `README.txt`** — Plaintext installation guide for DMG (drag to Applications, right-click Open, permissions, getting started, support contact)
- **NEW: `WelcomeView.swift`** — First-launch sheet explaining 3 permissions (mic, speech recognition, auto-updates) with "Get Started" button. Uses `UserDefaults "hasLaunchedBefore"` flag.
- **Modified `ContentView.swift`**: Added `showWelcome` state, `.sheet(isPresented: $showWelcome) { WelcomeView() }`

#### Build Verification
- Full Debug build succeeded with all new files + Sparkle dependency
- Sparkle SPM package resolved and compiled

### Files changed
| Action | File |
|--------|------|
| Edit | `ScriptFlow/build.sh` — Textream → ScriptFlow, version stamp, codesign |
| New | `ScriptFlow/ScriptFlow/ScriptLoader.swift` — remote fetch + cache + fallback |
| Edit | `ScriptFlow/ScriptFlow/ContentView.swift` — ScriptLoader integration, welcome sheet, source indicator |
| Edit | `ScriptFlow/ScriptFlow/ScriptFlowApp.swift` — Sparkle init + Check for Updates menu |
| Edit | `ScriptFlow/Info.plist` — Sparkle feed URL + auto-check keys |
| Edit | `ScriptFlow/ScriptFlow.xcodeproj/project.pbxproj` — Sparkle SPM dependency |
| New | `ScriptFlow/appcast.xml` — Sparkle update feed template |
| New | `ScriptFlow/README.txt` — DMG installation instructions |
| New | `ScriptFlow/ScriptFlow/WelcomeView.swift` — first-run permissions explainer |

### Where we left off
M5 Distribution fully implemented and building. TODO before first release:
1. Replace `OWNER/REPO` placeholders in ScriptLoader.swift, Info.plist, and appcast.xml with actual GitHub repo
2. Push to GitHub, tag v0.1.0, create release with DMG + appcast.xml + aca-script.md
3. EdDSA signing for Sparkle can be added later for extra security

### Next actions
1. Set up GitHub repository and replace OWNER/REPO placeholders
2. Run `./build.sh` to produce first DMG
3. Manual QA of WelcomeView first-run flow
4. Continue M3/M4: BranchManager, global hotkeys, practice mode
