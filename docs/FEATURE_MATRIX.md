# Feature Matrix — ScriptFlow

> Native macOS teleprompter for FHE sales agents with on-device speech tracking

| Field | Value |
|-------|-------|
| **Generated** | 2026-04-07 |
| **Last Reconciled** | 2026-04-07 |
| **Sources Scanned** | 13 Swift files, 4 git commits, PRD.md, TASKS.md, PROGRESS.md, PLAN.md, CONTEXT.md, TEST_LOG.md |
| **Project Status** | Stale (last commit 2026-02-09, 4 commits total) |
| **Version** | v0.1.0 (released on GitHub) |
| **Stack** | Swift / SwiftUI / macOS 15+ / Apple Speech Framework / Sparkle |
| **Repo** | github.com/ehoyos007/scriptflow (public) |

---

## Current State Summary

| Metric | Count |
|--------|-------|
| Swift source files | 13 |
| Total lines of code | 4,080 |
| Views / UI components | 6 (ContentView, MarqueeTextView, PhaseBarView, SettingsView, WelcomeView, NotchOverlayController) |
| Data models | 3 (ScriptModel, ScriptParser, BranchManager) |
| Services | 2 (SpeechRecognizer, ScriptLoader) |
| Config / Settings | 2 (NotchSettings, ScriptFlowApp) |
| Unit tests | 0 |
| UI tests | 0 |
| Automated CI | None |
| Deployment | DMG via GitHub Releases (v0.1.0) |
| Known bugs | 2 (audio device picker failure, tracking lag) |

---

## What Works

| ID | Feature | Evidence |
|----|---------|----------|
| F20 | Floating always-on-top overlay window | Session 7+: drag, resize, glass effect, position persistence |
| F21 | Markdown script parser with phases/branches/cues | ScriptParser.swift (142 LOC), ScriptModel.swift (156 LOC) |
| F22 | On-device speech recognition word tracking | SpeechRecognizer.swift (630 LOC), verified advancing in Session 12 logs |
| F23 | 5-type script rendering (speakable, coaching, placeholder, branch label, phase header) | MarqueeTextView.swift (585 LOC), Session 7 build verified |
| F24 | Phase progress bar with clickable segments | PhaseBarView.swift (133 LOC), proportional sizing by speakable content |
| F25 | Off-script detection with visual badge | Orange capsule badge, rolling quality window, freeze/re-engage logic |
| F26 | Remote script loading with 3-tier fallback | ScriptLoader.swift: GitHub Release > local cache > bundled resource |
| F27 | Sparkle auto-update framework | SPM dependency, appcast.xml, Check for Updates menu item |
| F28 | DMG distribution pipeline | build.sh: universal binary, ad-hoc codesign, version-stamped DMG |
| F29 | First-run welcome flow | WelcomeView.swift: permissions explainer, hasLaunchedBefore flag |
| F30 | v0.1.0 GitHub Release | DMG + appcast.xml + aca-script.md assets, QA'd install flow |
| F31 | Dark theme teleprompter color scheme | High-contrast: white speakable, coral coaching, gold placeholders, cyan branches |
| F32 | Classic/silence-paused/word-tracking listening modes | 3 modes with fallback auto-scroll |
| F33 | Settings persistence (UserDefaults) | Font, size, accent color, opacity, dimensions, glass effect |
| F34 | ACA Script 2.0 bundled | aca-script.md: 8 phases, ~15 branches, ~20 placeholders, ~12 coaching cues |

---

## What Does Not Work

| ID | Issue | Root Cause | Severity |
|----|-------|------------|----------|
| B1 | Audio device picker fails (Jabra device 92) | AudioUnitSetProperty breaks AVAudioEngine; fallback to system default works | Medium |
| B2 | Speech tracking lag (200-500ms) | Apple Speech Framework inherent partial result latency | Medium |
| B3 | os_log debug instrumentation still in code | Not yet stripped from SpeechRecognizer.swift | Low |
| B4 | Off-script detection not QA'd with working tracking | Session 11 broke tracking before QA could happen | Medium |
| B5 | No automated tests exist | TEST_LOG.md has strategy but zero test sessions recorded | High |

---

## Quadrant Map

```
                        HIGH IMPACT
                            |
              Q1            |           Q2
         Quick Wins         |      Strategic Bets
                            |
   F1  Strip debug logs     |  F5  WhisperKit integration
   F2  QA off-script        |  F6  Global hotkeys
   F3  Device picker UX     |  F7  Practice mode
   F4  File watcher reload  |  F8  BranchManager toggles
                            |
  ---- LOW EFFORT ----------+---------- HIGH EFFORT ----
                            |
              Q3            |           Q4
          Fill-ins          |          Defer
                            |
   F9  Simplify SettingsView|  F13 CRM integration
   F10 Unit tests (parser)  |  F14 Cloud script sync
   F11 EdDSA Sparkle signing|  F15 Analytics dashboard
   F12 App icon polish      |  F16 Multi-user admin
                            |
                        LOW IMPACT
```

---

## Shipped Features

| ID | Feature | Status | Milestone | Ship Date |
|----|---------|--------|-----------|-----------|
| F20 | Floating overlay window | Shipped | M1 | 2026-02-09 |
| F21 | Script parser (Markdown) | Shipped | M2 | 2026-02-09 |
| F22 | Speech-tracked word highlighting | Shipped | M1 | 2026-02-09 |
| F23 | 5-type script rendering | Shipped | M2 | 2026-02-09 |
| F24 | Phase progress bar | Shipped | M2 | 2026-02-09 |
| F25 | Off-script detection | Shipped (needs QA) | M6 | 2026-02-11 |
| F26 | Remote script loading | Shipped | M5 | 2026-02-09 |
| F27 | Sparkle auto-updates | Shipped | M5 | 2026-02-09 |
| F28 | DMG build pipeline | Shipped | M5 | 2026-02-09 |
| F29 | First-run welcome flow | Shipped | M5 | 2026-02-09 |
| F30 | v0.1.0 GitHub Release | Shipped | M5 | 2026-02-09 |
| F31 | Dark theme color scheme | Shipped | M2 | 2026-02-09 |
| F32 | 3 listening modes | Shipped | M1 | 2026-02-09 |
| F33 | Settings persistence | Shipped | M1 | 2026-02-09 |
| F34 | ACA Script 2.0 bundled | Shipped | M2 | 2026-02-09 |

---

## Q1 — Quick Wins (Low Effort / High Impact)

| ID | Feature | Status | Complexity | Impact | Sprint | Dependencies |
|----|---------|--------|------------|--------|--------|--------------|
| F1 | Strip os_log debug instrumentation | Not started | XS (1pt) | Medium | S1 | None |
| F2 | QA off-script detection end-to-end | Not started | S (2pt) | High | S1 | F1 (clean logs first) |
| F3 | Device picker graceful UX (warning + auto-fallback) | Not started | S (2pt) | High | S1 | None |
| F4 | File watcher for script hot-reload (FSEvents) | Not started | M (3pt) | Medium | S1 | None |

**Q1 Total: 8 points**

---

## Q2 — Strategic Bets (High Effort / High Impact)

| ID | Feature | Status | Complexity | Impact | Sprint | Dependencies |
|----|---------|--------|------------|--------|--------|--------------|
| F5 | WhisperKit integration (replace Apple Speech) | Not started | XL (8pt) | High | S2-S3 | None |
| F6 | Global hotkeys (play/pause, speed, section jump, show/hide) | Not started | L (5pt) | High | S2 | None |
| F7 | Practice mode (rehearsal without live call) | Not started | L (5pt) | High | S2 | None |
| F8 | BranchManager state toggles (highlight/dim branches) | Stub exists | M (3pt) | High | S2 | BranchManager.swift exists (47 LOC stub) |

**Q2 Total: 21 points**

---

## Q3 — Fill-ins (Low Effort / Low Impact)

| ID | Feature | Status | Complexity | Impact | Sprint | Dependencies |
|----|---------|--------|------------|--------|--------|--------------|
| F9 | Simplify SettingsView (remove unused, add ScriptFlow-specific) | Not started | S (2pt) | Low | S2 | None |
| F10 | Unit tests for ScriptParser + ScriptModel | Not started | M (3pt) | Medium | S1 | None |
| F11 | EdDSA signing for Sparkle updates | Not started | S (2pt) | Low | S3 | None |
| F12 | App icon polish (replace placeholder) | Not started | XS (1pt) | Low | S3 | Design asset needed |

**Q3 Total: 8 points**

---

## Q4 — Defer (High Effort / Low Impact for v1)

| ID | Feature | Status | Complexity | Impact | Sprint | Dependencies |
|----|---------|--------|------------|--------|--------|--------------|
| F13 | CRM integration | Out of scope | XL (8pt) | Low (v1) | -- | CRM API access |
| F14 | Cloud-based script syncing | Out of scope | L (5pt) | Low (v1) | -- | Backend infrastructure |
| F15 | Analytics / call tracking dashboard | Out of scope | XL (8pt) | Low (v1) | -- | Data pipeline |
| F16 | Multi-user admin panel | Out of scope | L (5pt) | Low (v1) | -- | Backend + auth |

**Q4 Total: 26 points (deferred)**

---

## Sprint Plan

### Sprint 1 — Stabilize & QA (8 pts)

| ID | Task | Points |
|----|------|--------|
| F1 | Strip debug logs | 1 |
| F2 | QA off-script detection | 2 |
| F3 | Device picker UX fix | 2 |
| F10 | Unit tests (parser/model) | 3 |

### Sprint 2 — Core Features (13 pts)

| ID | Task | Points |
|----|------|--------|
| F4 | File watcher hot-reload | 3 |
| F6 | Global hotkeys | 5 |
| F7 | Practice mode | 5 |

### Sprint 3 — Branch System & Polish (8 pts)

| ID | Task | Points |
|----|------|--------|
| F8 | BranchManager toggles | 3 |
| F9 | Simplify SettingsView | 2 |
| F11 | EdDSA Sparkle signing | 2 |
| F12 | App icon polish | 1 |

### Sprint 4+ — Performance (8 pts)

| ID | Task | Points |
|----|------|--------|
| F5 | WhisperKit integration | 8 |

---

## Story Point Summary

| Category | Points |
|----------|--------|
| Shipped (15 features) | -- (done) |
| Q1 Quick Wins | 8 |
| Q2 Strategic Bets | 21 |
| Q3 Fill-ins | 8 |
| Q4 Deferred | 26 |
| **Total Remaining (Q1-Q3)** | **37** |
| **Total with Deferred** | **63** |

---

## Milestone Status

| Milestone | Status | Completion |
|-----------|--------|------------|
| M1: Foundation | Done | 100% |
| M2: Script Engine | Done | 100% |
| M3: Branch System | Not started | 0% — BranchManager stub exists but no toggle UI |
| M4: Polish & Practice | Not started | 0% — Hotkeys, practice mode, settings cleanup |
| M5: Distribution | Done | 100% — v0.1.0 released |
| M6: Speech Accuracy | Partial | 40% — Off-script detection coded but not QA'd, WhisperKit not started |

---

## Notes

- **Stale since 2026-02-09** (last code commit). Sessions 11-12 on 2026-02-11 produced uncommitted work (off-script detection fixes, audio device debugging). Check working tree for uncommitted changes.
- **BranchManager.swift** exists as a 47-line stub but has no UI integration. The PRD requires branch toggle controls for conditional sections.
- **No tests exist** — TEST_LOG.md defines a strategy but has zero recorded test sessions. ScriptParser and ScriptModel are the best candidates for unit tests.
- **WhisperKit** is the planned replacement for Apple Speech Framework to reduce tracking latency. This is the highest-effort remaining item.
- **EdDSA signing** is needed before Sparkle can verify update authenticity. Currently updates are unsigned.
