# ScriptFlow — Test Log

> QA activities, test results, and bug tracking.

---

## Test Strategy

### Manual Testing Areas
| Area | What to Test |
|------|-------------|
| **Speech Recognition** | Word tracking accuracy, fuzzy matching, microphone switching, fallback behavior |
| **Script Parsing** | Valid Markdown loading, malformed file handling, hot-reload on file change |
| **Overlay Rendering** | Floating window positioning, resize, always-on-top, drag behavior |
| **Phase Bar** | Correct section tracking, progress updates, click-to-jump navigation |
| **Branch Rendering** | IF block display, highlight/dim toggling, nested conditions |
| **Coaching Cues** | Distinct styling, not interfering with speech tracking |
| **Placeholders** | Visual rendering, not read by speech recognizer |
| **Global Hotkeys** | All shortcuts work when app not focused, no conflicts with OS/other apps |
| **Practice Mode** | Full teleprompter experience, section replay, no live-call dependencies |
| **Settings** | Persistence across restarts, real-time preview of changes |
| **DMG Distribution** | Build succeeds, installs correctly, runs after xattr clear |

### Automated Testing
- Unit tests for `ScriptParser` (Markdown → data model)
- Unit tests for `BranchManager` (state toggling)
- Unit tests for `ScriptPhase` model validation

---

## Test Sessions

(No test sessions yet — development has not started)
