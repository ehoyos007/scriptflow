# ScriptFlow — Implementation Plan

> Strategic planning for feature development.

---

## M1: Foundation

### Objective
Get a running macOS app that loads and displays a script in a floating window with basic speech-tracked scrolling.

### Steps

1. **Clone Textream** — `git clone https://github.com/f/textream` into a working directory
2. **Create ScriptFlow Xcode project** — Either fork the existing project or create a new SwiftUI project and port files
3. **Verify Textream builds** — Ensure the base app compiles and runs on the development machine
4. **Strip unneeded components:**
   - `ExternalDisplayController.swift` — remove entirely
   - `UpdateChecker.swift` — remove entirely
   - `TextreamService.swift` — remove URL scheme handler
   - Notch overlay mode in `NotchOverlayController.swift` — remove, keep floating window only
5. **Rebrand:**
   - Rename `TextreamApp` → `ScriptFlowApp`
   - Update bundle identifier, app name, window title
   - Placeholder app icon
6. **Floating window as default:**
   - Ensure the floating window overlay is the primary (and only) display mode
   - Verify drag, resize, always-on-top, glass effect
   - Persist window position/size
7. **Basic script loading:**
   - Create a simple `script.md` file with the first page of the ACA script
   - Build a minimal `ScriptParser` that reads Markdown and outputs plain text blocks
   - Feed parsed text into the existing `MarqueeTextView`
8. **Verify speech tracking works** — Ensure on-device speech recognition still functions with the new text source
9. **Dark theme baseline** — Switch the overlay to dark background with light text

### Dependencies
- Xcode 16+ installed
- macOS 15 Sequoia
- Microphone permissions granted

### Risks
- Textream's Xcode project structure may need significant reworking to rename/rebrand
- Speech recognition permissions may need re-configuration after bundle ID change

---

## M2-M5: Planned (details to be added as M1 completes)

See PRD.md § Milestones and TASKS.md for full scope.
