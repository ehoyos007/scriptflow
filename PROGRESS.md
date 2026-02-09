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
