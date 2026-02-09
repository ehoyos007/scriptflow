# ScriptFlow — Task Tracker

> Active task tracking for ScriptFlow development.

## Current Sprint: M1 — Foundation

### Backlog

- [ ] **Fork Textream codebase** — Clone repo, set up Xcode project, verify builds
- [ ] **Rebrand to ScriptFlow** — Rename app, update bundle ID, app icon placeholder, window titles
- [ ] **Strip unnecessary components** — Remove External Display controller, Update Checker, notch mode, URL scheme handler
- [ ] **Implement floating window mode** — Ensure floating overlay works as primary display (draggable, resizable, always-on-top)
- [ ] **Design script file format** — Define Markdown schema for phases, branches, coaching cues, placeholders
- [ ] **Build ScriptParser** — Parse Markdown script file into structured data model
- [ ] **Create ScriptPhase data model** — Swift structs for phases, text blocks, branches, cues, placeholders
- [ ] **Convert ACA Script 2.0 to Markdown format** — Transform PDF content into the new script file format
- [ ] **Implement script loading** — Load script from external Markdown file, validate, and render
- [ ] **Redesign color scheme** — Dark background, high-contrast teleprompter theme with distinct styles for each element type
- [ ] **Implement coaching cue rendering** — Red/coral italic styling for agent-only instructions
- [ ] **Implement placeholder rendering** — Yellow/gold highlighted brackets for fill-in fields
- [ ] **Build PhaseBarView** — Progress indicator showing current section and overall progress
- [ ] **Implement conditional branch rendering** — Visual badges, highlight/dim states for IF blocks
- [ ] **Build BranchManager** — State management for toggling branch relevance
- [ ] **Implement global hotkeys** — System-wide keyboard shortcuts (play/pause, speed, section jump, show/hide)
- [ ] **Add practice mode** — Rehearsal mode accessible from main window
- [ ] **Implement fallback scroll mode** — Classic auto-scroll when speech recognition unavailable
- [ ] **Simplify SettingsView** — Remove unneeded settings, add ScriptFlow-specific options
- [ ] **File watcher for script hot-reload** — FSEvents-based auto-reload on script file changes
- [ ] **Build DMG for distribution** — Universal binary build script adapted from Textream
- [ ] **Write agent onboarding guide** — Quick-start instructions for agents

### In Progress

(none yet)

### Done

(none yet)

---

## Milestone Overview

| Milestone | Status | Focus |
|-----------|--------|-------|
| M1: Foundation | **Next Up** | Fork, rebrand, floating window, basic script loading |
| M2: Script Engine | Backlog | Parser, phase model, coaching cues, placeholders, phase bar |
| M3: Branch System | Backlog | Conditional rendering, highlight/dim, branch toggles |
| M4: Polish & Practice | Backlog | Practice mode, hotkeys, settings, fallback scroll |
| M5: Distribution | Backlog | DMG build, team rollout, onboarding docs |
