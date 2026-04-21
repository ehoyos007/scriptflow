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

#### Phase 5: GitHub Repo + First Release
- Created private repo: `ehoyos007/scriptflow`
- Replaced all `OWNER/REPO` placeholders with `ehoyos007/scriptflow` in ScriptLoader.swift, Info.plist, appcast.xml
- Built universal DMG: `ScriptFlow-0.1.0.dmg` (arm64 + x86_64, ad-hoc signed)
- Tagged `v0.1.0`, pushed, created GitHub Release with 3 assets: DMG, appcast.xml, aca-script.md
- Release URL: https://github.com/ehoyos007/scriptflow/releases/tag/v0.1.0

### Where we left off
M5 Distribution complete. v0.1.0 released on GitHub with DMG ready for agent distribution. All OWNER/REPO placeholders resolved. EdDSA signing for Sparkle can be added later.

### Next actions
1. Manual QA of WelcomeView first-run flow (mount DMG, drag to Apps, right-click Open)
2. Verify ScriptLoader fetches aca-script.md from the release (once an agent installs)
3. Continue M3/M4: BranchManager, global hotkeys, practice mode, simplify SettingsView

---

## Session 10 — 2026-02-09

### What happened
- **GitHub repo setup:** Created `ehoyos007/scriptflow`, pushed all code, replaced all `OWNER/REPO` placeholders
- **Built DMG:** `./build.sh` produced `ScriptFlow-0.1.0.dmg` — universal binary (arm64 + x86_64), ad-hoc signed, README.txt included
- **First release:** Tagged `v0.1.0`, created GitHub Release with 3 assets: DMG, appcast.xml, aca-script.md
- **Made repo public:** Private repos don't support anonymous release asset downloads — switched to public so agents can download without auth
- **QA'd full install flow:**
  - Mounted DMG: contains ScriptFlow.app, Applications symlink, README.txt
  - Codesign verified: adhoc, bundle ID `com.firsthealthenrollment.scriptflow`
  - Info.plist confirmed: SUFeedURL, mic/speech descriptions, version 0.1.0
  - Launched from temp dir (simulating agent install): WelcomeView appeared on first launch
  - ScriptLoader successfully fetched aca-script.md from GitHub Release and cached to `~/Library/Caches/com.fhe.ScriptFlow/cached-aca-script.md` (14707 bytes)
  - Speech authorization prompt fired on launch
  - All release download URLs verified working (aca-script.md, appcast.xml, DMG)

### QA results
| Check | Result |
|-------|--------|
| DMG contents (app + Applications + README) | Pass |
| Universal binary (arm64 + x86_64) | Pass |
| Ad-hoc codesign | Pass |
| Info.plist keys (Sparkle, permissions, version) | Pass |
| WelcomeView on first launch | Pass |
| ScriptLoader remote fetch + cache | Pass |
| Release asset URLs (public) | Pass |
| Bundled aca-script.md fallback | Pass |

### Where we left off
v0.1.0 fully released, QA'd, and ready for agent distribution. Download link: `https://github.com/ehoyos007/scriptflow/releases/latest/download/ScriptFlow-0.1.0.dmg`

### Next actions
1. Distribute to agents
2. Continue M3/M4: BranchManager, global hotkeys, practice mode, simplify SettingsView

---

## Session 11 — 2026-02-11

### What happened
Implemented **Phase 1: Matching Algorithm Overhaul + Off-Script Detection** to fix false progression during live calls.

#### Problem
Agents reported the teleprompter advancing when they chatted off-script with clients. Root cause: overly permissive fuzzy matching (substring matches like `"I"` matching `"fire"`, loose edit distances, no concept of "off-script" state).

#### Changes to SpeechRecognizer.swift

**1. New off-script detection system:**
- Added `isOffScript` observable property + rolling quality window
- `matchQualityWindow` tracks last 5 match quality scores (0.0–1.0)
- **Off-script trigger**: quality < 0.15 for 3 consecutive results → freeze `recognizedCharCount`, set `isOffScript = true`
- **Re-engagement**: quality >= 0.4 for 2 consecutive results → resume from frozen position
- `resetOffScriptState()` called in `jumpTo()`, `start()`, `resume()`

**2. MatchResult struct:**
- Both `charLevelMatch` and `wordLevelMatch` now return `MatchResult(advance:quality:)` instead of raw `Int`
- `charLevelMatch` quality = `matchedChars / spokenAlphanumCount`
- `wordLevelMatch` quality = `matchedSourceWords / spokenWordsConsumed`

**3. Consecutive-match confirmation buffer (wordLevelMatch):**
- Single lucky word matches (e.g., "the", "I") no longer advance the teleprompter
- Advancement only committed after 2+ consecutive word matches
- Pending buffer tracks uncommitted chars/words, resets on miss

**4. Tightened isFuzzyMatch thresholds:**
| Rule | Before | After |
|------|--------|-------|
| Substring match | `a.contains(b)` | **Removed** |
| Prefix match | Any length | >= 4 chars only |
| Shared prefix | 60%, min 2 | 75%, min 3 chars |
| Edit dist (<=4 chars) | <= 1 | == 0 (exact only) |
| Edit dist (5-8 chars) | <= 2 | <= 1 |
| Edit dist (>8 chars) | <= len/3 | <= len/4 |

**5. Reduced re-sync tolerance:**
- `charLevelMatch` skip reduced from 3→2 chars, breaks instead of skipping both on mismatch
- `wordLevelMatch` skip reduced from 3→2 words

#### Changes to NotchOverlayController.swift

**6. OFF SCRIPT badge:**
- Orange capsule badge after AudioWaveformProgressView in both `NotchOverlayView` and `FloatingOverlayView`
- `lastSpokenText` dimmed to 0.2 opacity while off-script (normally 0.5)
- Animated with `.transition(.scale.combined(with: .opacity))`

#### Build
- `xcodebuild -scheme ScriptFlow -configuration Debug build` → **BUILD SUCCEEDED** (zero errors)

### Files changed
| File | Changes |
|------|---------|
| `SpeechRecognizer.swift` | Off-script state, MatchResult struct, quality scoring, consecutive-match buffer, tightened isFuzzyMatch, reduced skip tolerances |
| `NotchOverlayController.swift` | OFF SCRIPT badge in both overlay views, dimmed lastSpokenText |

### Testing revealed: tracking completely broken

After initial implementation, word tracking stopped advancing entirely. Two rounds of fixes attempted:

#### Round 1 — Identified 3 bugs
1. **`charLevelMatch` `break` too aggressive** — Changed mismatch from skip-both to `break`, which killed the entire match on any STT discrepancy. **Fix**: Restored skip-both (without counting as matched char for quality).
2. **`wordLevelMatch` quality=0 for uncommitted** — Short Apple Speech partial results (1 word) never committed (needs 2 consecutive), so `quality=0.0`. Three of these → off-script → frozen forever. **Fix**: Quality now computed from ALL matches seen (committed + pending), not just committed.
3. **Off-script triggers on tiny results** — Added `minSpokenWordsForOffScript = 3` threshold so partial results like "hello" don't trigger off-script detection.

#### Round 2 — Still broken
After fixes, tracking still didn't advance. Investigation revealed:
- Audio engine IS starting (CoreAudio logs confirm aggregateDevice creation, Scarlett 2i2 detected)
- Audio waveform in overlay shows levels (audio tap callback IS running)
- BUT: `matchCharacters()` may not be called, OR the recognition task callback may not fire
- Added NSLog instrumentation to `matchCharacters`, `beginRecognition`, and recognition task error handler
- `xcodebuild build` was NOT recompiling despite source changes — incremental build cache stale
- **Solution found**: `xcodebuild clean build` required. Verified NSLog strings present in `ScriptFlow.debug.dylib` (NOT the main binary — Swift Debug builds use a separate dylib)
- Clean-built binary launched but **logs not yet captured** — session ended before next test

#### Audio input device picker (also implemented)
- `NotchSettings.swift`: Added `selectedAudioDeviceID` (AudioDeviceID, UserDefaults-persisted), `availableAudioInputDevices()` CoreAudio enumeration
- `SettingsView.swift`: Microphone picker in Speech tab (System Default + all input devices)
- `SpeechRecognizer.swift`: `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` on inputNode before engine start

### Where we left off

**CRITICAL: The app is in a debuggable state with NSLog instrumentation. The very next step is to capture logs.**

The clean-built binary at `DerivedData/.../Debug/ScriptFlow.app` has 3 NSLog calls:
1. `[Engine] started. device=%d format=%@ sourceLen=%d` — in `beginRecognition()` after `audioEngine.start()`
2. `[Engine] sourceText prefix: "%@"` — shows what text is being matched against
3. `[Match] spoken="%@" | charAdv=%d charQ=%.2f | wordAdv=%d wordQ=%.2f | offset=%d recognized=%d offScript=%d | source="%@"` — in `matchCharacters()`, shows both matchers' results
4. `[SpeechTask] error: %@` — in recognition task error callback

**To capture logs next session:**
```bash
# 1. Kill any running instance
pkill -9 -f ScriptFlow

# 2. Clean build (REQUIRED — incremental builds don't pick up changes!)
cd /Users/enzohoyos/Projects/fhe-smart-script/ScriptFlow
xcodebuild -scheme ScriptFlow -configuration Debug clean build

# 3. Launch the app
open /path/to/DerivedData/.../Debug/ScriptFlow.app

# 4. Start teleprompter, speak for 10 seconds

# 5. Capture logs (NSLog goes to unified log, NOT stdout)
/usr/bin/log show --predicate 'process == "ScriptFlow"' --last 2m | grep "\[Engine\]\|\[Match\]\|\[SpeechTask\]"
```

**Possible root causes (ranked by likelihood):**
1. **Recognition task callback never fires** — `SFSpeechRecognizer.recognitionTask()` starts but Apple Speech never returns results (permission issue? network issue with on-device model not loaded?)
2. **`beginRecognition()` never called** — Auth callback returns non-authorized, or `listeningMode != .wordTracking`
3. **Audio device setting breaks the pipeline** — `AudioUnitSetProperty` with a non-zero device ID causes the speech recognizer to not receive audio

**Quick sanity test**: Set audio device back to "System Default" (0) in settings, restart teleprompter, check if tracking works. If it does, the bug is in the device selection code.

### Files changed (uncommitted)
| File | Changes |
|------|---------|
| `SpeechRecognizer.swift` | +CoreAudio import, +isOffScript state, +MatchResult struct, +off-script detection in matchCharacters, +quality scoring in both matchers, +consecutive-match buffer in wordLevelMatch, tightened isFuzzyMatch, +resetOffScriptState(), +audio device selection, +3 NSLog debug lines |
| `NotchOverlayController.swift` | +OFF SCRIPT badge in both overlay views, dimmed lastSpokenText |
| `NotchSettings.swift` | +CoreAudio import, +selectedAudioDeviceID property, +AudioInputDevice struct, +availableAudioInputDevices() |
| `SettingsView.swift` | +CoreAudio import, +audioInputSection with Microphone picker |
| `TASKS.md` | Updated with current sprint status |
| `PROGRESS.md` | This session log |

### Next actions
1. **Capture NSLog output** — Follow the steps above to get log data showing whether `beginRecognition` reaches engine start and whether `matchCharacters` is called
2. **If no `[Engine]` log** → Speech auth is failing or `listeningMode` is wrong. Check `SFSpeechRecognizer.requestAuthorization` callback.
3. **If `[Engine]` but no `[Match]`** → Recognition task isn't returning results. Try with "System Default" mic. Check if Apple Speech needs network.
4. **If `[Match]` shows advance=0** → Matching algorithm issue. Log will show spoken text vs source text to diagnose.
5. **Once tracking works** → Remove NSLog instrumentation, QA the off-script detection, then continue to Phase 2 (WhisperKit).

---

## Session 12 — 2026-02-11

### What happened
Debugged and fixed the word tracking regression from Session 11. Root cause was **two separate bugs**, not the matching algorithm.

#### Bug 1: NSLog invisible in unified log
- `NSLog()` from Swift in a debug dylib is silently suppressed by macOS unified logging
- All 3 NSLog calls from Session 11 were compiled into `ScriptFlow.debug.dylib` but produced zero output in `log show`
- **Fix**: Switched to `os_log(.error, log:)` with explicit subsystem `com.fhe.ScriptFlow` and category `SpeechRecognizer` — error-level logs cannot be suppressed
- **Memory note**: NSLog doesn't work for debugging in this project; always use `os_log(.error)` with a custom subsystem

#### Bug 2: AudioUnitSetProperty breaks AVAudioEngine (the actual tracking blocker)
- `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` with device ID 92 (Jabra SPEAK 510 USB) reported success (status=0) but put AVAudioEngine into an invalid state
- `audioEngine.start()` threw error -10868 (`kAudioUnitErr_InvalidPropertyValue`) every time
- The retry loop burned through all 10 retries, each failing identically → `isListening = false` → tracking dead
- This was the SOLE reason tracking stopped: the engine never started, so the recognition task never received audio
- **Fix**: Added `usingFallbackDevice` flag — if custom device fails, immediately retry with system default (device 0). Engine starts successfully on fallback.

#### Bug 3: Device fallback flag reset too early
- After fallback to device 0 worked, `usingFallbackDevice` was reset to `false` on engine start
- Next "No speech detected" error → retry → back to broken device 92 → fail → fallback → repeat
- This created an 18-second retry storm (20+ cycles) before tracking could begin
- **Fix**: Only reset `usingFallbackDevice` when we get an actual recognition result, not just a successful engine start. Also reset in `start()` for fresh user-initiated sessions.

#### Fix 4: matchStartOffset never advancing on recognition restart
- Apple Speech recognition tasks timeout after ~1 minute with "No speech detected" error
- On error retry, `matchStartOffset` stayed at 0, causing re-scanning from the beginning
- **Fix**: Set `matchStartOffset = recognizedCharCount` in the error-retry path so new sessions resume from current position

#### Log instrumentation added (to be removed later)
Replaced all NSLog with `os_log(.error)` at these points:
- `start()`: sourceText.count
- Auth callback: status value
- `beginRecognition()`: entered, selectedDevice, fallback flag, AudioUnitSetProperty status, recordingFormat, engine start result
- Recognition task: result text, error text
- `matchCharacters()`: spoken/source preview, charAdv/wordAdv, quality scores, offset, recognized count, offScript flag

#### Tracking verified working
After fixes, logs confirmed:
1. Device 92 fails → immediate fallback to device 0 → engine starts in <200ms
2. Recognition results arrive within ~2s of engine start
3. charLevelMatch advances correctly: 3→19→26→29→35→40→48→55→65→83→96→123→153→183 chars over ~10s of speech
4. Quality scores healthy: charQ 0.70-0.88, not triggering off-script

#### Remaining lag observation
User reported "heavy lag" in tracking. Analysis of logs shows:
- Apple Speech partial results have inherent 200-500ms latency
- Initial 2s warmup before first word recognized
- `matchStartOffset=0` throughout session (Apple Speech gives cumulative results, so offset can't advance mid-session without breaking matching)
- The `matchStartOffset` fix on restart will help for long scripts where sessions timeout and restart

### Files changed (uncommitted)
| File | Changes |
|------|---------|
| `SpeechRecognizer.swift` | +os_log import, +dbg OSLog, NSLog→os_log, +usingFallbackDevice with persist-across-retries, engine-first ordering, matchStartOffset advance on restart, fallback reset only on real results |

### Where we left off
Word tracking is **working** but with moderate lag from Apple Speech latency. Latest build deployed and tested. Still need to:
1. QA off-script detection with the working tracking
2. QA the lag after matchStartOffset fix (should improve on recognition restarts)
3. Remove os_log debug instrumentation once satisfied
4. Fix the device picker — device 92 (Jabra SPEAK 510) fails with AudioUnitSetProperty; may need aggregate device approach or just graceful UI feedback

### Next actions
1. Test the latest build (matchStartOffset fix, persistent fallback) — verify faster startup and less lag on recognition restarts
2. QA off-script detection: speak off-script deliberately, verify orange badge appears, resume on-script
3. If lag is still unacceptable, consider WhisperKit (Phase 2) for lower latency
4. Remove os_log instrumentation after QA
5. Fix device picker UX — show warning if selected device fails, auto-select working device
