# ScriptFlow — Task Tracker

> Active task tracking for ScriptFlow development.

## Current Sprint: M1 — Foundation

### Backlog

- [ ] **Build BranchManager** — State management for toggling branch relevance
- [ ] **Implement global hotkeys** — System-wide keyboard shortcuts (play/pause, speed, section jump, show/hide)
- [ ] **Add practice mode** — Rehearsal mode accessible from main window
- [ ] **Simplify SettingsView** — Remove unneeded settings, add ScriptFlow-specific options
- [ ] **File watcher for script hot-reload** — FSEvents-based auto-reload on script file changes

### In Progress

- [ ] **Manual QA: overlay rendering** — Verify all 5 word types display correctly in teleprompter overlay

### Done

- [x] **Fork Textream codebase** — Clone repo, set up Xcode project, verify builds
- [x] **Rebrand to ScriptFlow** — Rename app, update bundle ID, window titles
- [x] **Strip unnecessary components** — Remove External Display controller, Update Checker, notch mode, URL scheme handler
- [x] **Implement floating window mode** — Floating overlay works as primary display (draggable, resizable, always-on-top)
- [x] **Design script file format** — Markdown schema for phases, branches, coaching cues, placeholders
- [x] **Build ScriptParser** — Parse Markdown script file into structured data model
- [x] **Create ScriptPhase data model** — Swift structs for phases, text blocks, branches, cues, placeholders
- [x] **Convert ACA Script 2.0 to Markdown format** — Transform PDF content into the new script file format
- [x] **Implement script loading** — Load script from external Markdown file, validate, and render
- [x] **Redesign color scheme** — Dark background, high-contrast teleprompter theme with distinct styles
- [x] **Implement coaching cue rendering** — Red/coral italic styling for agent-only instructions
- [x] **Implement placeholder rendering** — Yellow/gold highlighted brackets for fill-in fields
- [x] **Implement conditional branch rendering** — Visual cyan pill badges, highlight/dim states for IF blocks
- [x] **Implement fallback scroll mode** — Classic auto-scroll + silence-paused modes
- [x] **Build PhaseBarView** — Segmented progress bar with proportional phases, tap-to-jump, active/passed/upcoming states
- [x] **Fix build.sh (Textream → ScriptFlow)** — Version-stamped DMG, ad-hoc codesign, README in DMG
- [x] **Script auto-download (ScriptLoader)** — Remote fetch from GitHub Releases with cache + bundled fallback
- [x] **Sparkle auto-updates** — SPM dependency, updater init, Check for Updates menu, Info.plist keys, appcast.xml template
- [x] **First-run experience** — WelcomeView sheet (permissions explainer), README.txt for DMG
- [x] **Build DMG for distribution** — Universal binary build script adapted from Textream
- [x] **Set up GitHub repo + first release** — ehoyos007/scriptflow, v0.1.0 with DMG + appcast.xml + aca-script.md

---

## Milestone Overview

| Milestone | Status | Focus |
|-----------|--------|-------|
| M1: Foundation | **Done** | Fork, rebrand, floating window, basic script loading |
| M2: Script Engine | **In Progress** | Parser, phase model, coaching cues, placeholders, phase bar |
| M3: Branch System | Backlog | Conditional rendering, highlight/dim, branch toggles |
| M4: Polish & Practice | Backlog | Practice mode, hotkeys, settings, fallback scroll |
| M5: Distribution | **Done** | DMG build, Sparkle updates, script auto-download, first-run UX |
