# ScriptFlow — Task Tracker

> Active task tracking for ScriptFlow development.

## Current Sprint: Speech Tracking Accuracy

### In Progress

- [ ] **QA off-script detection** — Tracking works again; need to deliberately speak off-script, verify orange badge, verify re-engagement
- [ ] **QA tracking lag** — matchStartOffset now advances on recognition restart; need to test if lag improves over long sessions
- [ ] **Audio input device picker** — UI works but device 92 (Jabra) fails with AudioUnitSetProperty; fallback to system default works. Need graceful UX (show warning, auto-select working device).

### Backlog (Speech Accuracy)

- [ ] **Phase 2: WhisperKit integration** — Replace Apple Speech with WhisperKit for consistent latency + word confidence
- [ ] **Phase 3: Timestamp-aware matching** — Leverage WhisperKit per-word confidence for superior matching
- [ ] **Remove os_log debug instrumentation** — Strip os_log calls from SpeechRecognizer.swift once QA complete

### Backlog (Features)

- [ ] **Build BranchManager** — State management for toggling branch relevance
- [ ] **Implement global hotkeys** — System-wide keyboard shortcuts (play/pause, speed, section jump, show/hide)
- [ ] **Add practice mode** — Rehearsal mode accessible from main window
- [ ] **Simplify SettingsView** — Remove unneeded settings, add ScriptFlow-specific options
- [ ] **File watcher for script hot-reload** — FSEvents-based auto-reload on script file changes

### Done (This Sprint)

- [x] **Fix false progression in SpeechRecognizer** — Tightened isFuzzyMatch, consecutive-match confirmation in wordLevelMatch, quality scoring in both matchers
- [x] **Add off-script detection** — Rolling quality window, freeze on 3 consecutive misses, re-engage on 2 consecutive good matches
- [x] **Add OFF SCRIPT visual indicator** — Orange capsule badge in both overlay views, dimmed lastSpokenText
- [x] **Reset off-script state on user actions** — jumpTo, start, resume all clear off-script state
- [x] **Fix tracking regression (attempt 1)** — Restored skip-both in charLevelMatch, fixed wordLevelMatch quality to use all matches not just committed, added min spoken word threshold for off-script trigger
- [x] **Add audio input device enumeration** — CoreAudio device listing in NotchSettings, Picker in SettingsView
- [x] **Fix tracking regression (root cause)** — AudioUnitSetProperty broke AVAudioEngine; added device fallback, persistent fallback flag, matchStartOffset advance on restart

### Done (Previous)

- [x] Fork Textream, rebrand to ScriptFlow, strip unnecessary components
- [x] Implement floating window mode, script file format, ScriptParser, ScriptPhase model
- [x] Convert ACA Script 2.0, implement script loading, redesign color scheme
- [x] Coaching cues, placeholders, branch rendering, fallback scroll modes
- [x] PhaseBarView, build.sh, ScriptLoader, Sparkle, WelcomeView, DMG, GitHub release

---

## Milestone Overview

| Milestone | Status | Focus |
|-----------|--------|-------|
| M1: Foundation | **Done** | Fork, rebrand, floating window, basic script loading |
| M2: Script Engine | **In Progress** | Parser, phase model, coaching cues, placeholders, phase bar |
| M3: Branch System | Backlog | Conditional rendering, highlight/dim, branch toggles |
| M4: Polish & Practice | Backlog | Practice mode, hotkeys, settings, fallback scroll |
| M5: Distribution | **Done** | DMG build, Sparkle updates, script auto-download, first-run UX |
| M6: Speech Accuracy | **In Progress** | Off-script detection, tightened matching, WhisperKit |
