# ScriptFlow - Product Requirements Document

> A native macOS teleprompter for First Health Enrollment sales agents that uses on-device speech recognition to guide agents through the ACA enrollment script in real-time.

**Version:** 1.0
**Date:** 2026-02-09
**Status:** Draft
**Author:** First Health Enrollment Engineering

---

## 1. Problem Statement

Sales agents at First Health Enrollment read a 9-page ACA enrollment script during live customer calls. Currently, agents reference a static PDF while simultaneously operating CRM tools, Sherpa, and enrollment systems. This creates several problems:

- **Losing their place** in the script while multitasking across applications
- **Missing conditional branches** (e.g., Medicaid eligibility, gender-specific benefits, state-specific add-ons) that require quick mental navigation
- **Inconsistent pacing** — rushing through critical compliance disclosures or pausing awkwardly during transitions
- **Slow onboarding** — new agents struggle to internalize the script's flow, branching logic, and coaching cues

## 2. Proposed Solution

**ScriptFlow** is a native macOS teleprompter app, adapted from the open-source [Textream](https://github.com/f/textream) project, purpose-built for the First Health Enrollment ACA script. It overlays a floating, always-on-top window that uses on-device speech recognition to track the agent's spoken words and automatically highlight/scroll through the script in real-time.

### Core Differentiators from Textream

| Feature | Textream | ScriptFlow |
|---------|----------|------------|
| Use case | General-purpose streamer teleprompter | Insurance sales call script guidance |
| Script format | Plain text input | Structured script with phases, branches, coaching cues |
| Branching | None | Conditional sections (IF MEDICAID, IF MALE/FEMALE, etc.) visually distinguished |
| Phase tracking | None | Progress bar showing current section of the call |
| Coaching cues | None | Internal agent instructions rendered in distinct visual style |
| Script source | Paste-in text | External file (Markdown/JSON) for easy updates |
| Practice mode | None | Rehearsal mode for agent training |

## 3. Target Users

| User | Description | Count |
|------|-------------|-------|
| **Sales Agent** | Licensed insurance agents conducting ACA enrollment calls | <20 |
| **Script Admin** | Team lead or manager who updates the script file | 1-2 |

### Agent Environment During Calls

- macOS desktop (iMac or MacBook)
- Multiple apps open simultaneously: CRM, Sherpa (marketplace quoting tool), browser, softphone/VoIP
- Headset with microphone (for customer call + speech recognition input)
- Calls last 20-45 minutes on average

## 4. Feature Requirements

### 4.1 Teleprompter Core (P0 — Must Have)

#### 4.1.1 Speech-Tracked Word Highlighting
- Use Apple's on-device Speech framework (same as Textream) to recognize the agent's spoken words
- Highlight the current word in the script as the agent speaks
- Fuzzy matching to handle natural speech variations, filler words, and ad-libbing
- All processing on-device — no audio data leaves the Mac

#### 4.1.2 Floating Window Overlay
- Always-on-top window that stays visible over CRM, browser, Sherpa, etc.
- Draggable — agent positions it wherever convenient on their screen
- Resizable — adjustable width and height to fit their workspace
- Semi-transparent/glass effect option to see content underneath
- Remembers position and size between sessions

#### 4.1.3 Script Rendering
- Load script from an external file (Markdown or structured JSON) — not hardcoded
- Render speakable text in large, readable teleprompter font
- Render fill-in-the-blank placeholders (e.g., `[CUSTOMER NAME]`, `[SUBSIDY AMOUNT]`) in a distinct highlighted style so agents recognize them but don't read them literally
- Smooth vertical scrolling synchronized with speech recognition progress

#### 4.1.4 Global Hotkeys
System-wide keyboard shortcuts that work even when ScriptFlow is not the focused app:

| Action | Suggested Default |
|--------|------------------|
| Play / Pause | `⌘ + Shift + Space` |
| Speed up scroll | `⌘ + Shift + ↑` |
| Slow down scroll | `⌘ + Shift + ↓` |
| Jump to next section | `⌘ + Shift + →` |
| Jump to previous section | `⌘ + Shift + ←` |
| Show / Hide overlay | `⌘ + Shift + H` |

### 4.2 Script Structure & Visual Design (P0 — Must Have)

#### 4.2.1 Phase Progress Bar
A persistent indicator at the top of the overlay showing:
- Current section name (e.g., "PITCH", "CONSENT", "VERIFICATION")
- Progress within the overall script (e.g., visual bar or percentage)
- Clickable section labels to jump between phases

**Script Phases (from the ACA script):**
1. **Introduction** — Greeting, identify agent, call recording disclosure
2. **Probing** — Qualifying questions (zip code, tax filing, income, dependents, employment)
3. **Medical Needs** — Pre-existing conditions, prescriptions, doctor preferences
4. **Pitch** — Subsidy reveal, plan benefits presentation, dental/vision/accidental
5. **Close** — Pricing, payment collection, address, SSN, employer verification
6. **Consent** — ACA consent form, CareConnect verification form
7. **Disclosures** — Mandatory verbal consent disclosures and identity verification
8. **Wrap-Up** — Next steps, email expectations, Healthcare.gov warnings, referral ask

#### 4.2.2 Redesigned Color Scheme
Optimized for teleprompter readability (dark background, high-contrast text):

| Element | Style | Purpose |
|---------|-------|---------|
| **Speakable text** | White / light gray on dark background | Primary script content the agent reads aloud |
| **Coaching cues** | Red/coral italic, smaller font | Internal instructions (e.g., "DON'T PAUSE", "UNLOAD YOUR AMMUNITION") — visible but clearly not to be read aloud |
| **Placeholders** | Yellow/gold highlight with brackets | Fill-in fields like `[CUSTOMER NAME]`, `[SUBSIDY AMOUNT]` |
| **Conditional labels** | Cyan/teal badge | Branch markers like `IF MEDICAID`, `IF FEMALE`, `IF SECURITY` |
| **Highlighted branch** | Brighter text, subtle left border | The currently relevant branch content (when agent selects a condition) |
| **Phase dividers** | Horizontal rule + section title | Clear visual break between call phases |
| **Current word** | Accent color highlight (configurable) | The word currently being spoken, tracked by speech recognition |

#### 4.2.3 Conditional Branch Display
- All branches remain visible in the scroll at all times
- Each conditional section is prefixed with a visual label/badge (e.g., `IF FEMALE`, `IF SECURITY`)
- When a branch is relevant, it is visually emphasized (brighter, expanded, or bordered)
- When a branch is not relevant, it is visually dimmed but still readable
- Branch relevance can be toggled via:
  - Clickable badges/buttons on the conditional labels
  - Or simply left neutral (all branches shown at equal weight)

### 4.3 Script File Format (P0 — Must Have)

#### 4.3.1 External Script Loading
- Script stored as a structured file (Markdown with front matter, or JSON)
- App watches the file for changes and reloads automatically (hot-reload)
- File can be distributed via shared folder, Google Drive, or Slack

#### 4.3.2 Script Schema
The script file must support:

```
- Phases/sections with labels
- Speakable text blocks
- Coaching cues / agent instructions (non-speakable)
- Placeholder fields with labels
- Conditional branches with labels and conditions
- Emphasis/formatting (bold, underline) for key phrases
```

#### 4.3.3 Example Script Format (Markdown-based)

```markdown
---
title: "THE ACA Script"
version: "2.0"
updated: "2026-02-09"
---

## Introduction

Hey, [customer name]! This is [agent], a licensed agent for First Health
Enrollment in the state of [state]. I'm responding to your Obamacare
application that you submitted online looking for health insurance.
How can I help you?

Very good. Are you looking for an individual or a family plan?

> COACHING: This call will be recorded disclosure is MANDATORY.
> Do not skip this line.

Excellent! Well, first and foremost, I have to mention that this call
will be recorded or monitored for quality and training purposes.

## Probing

<!-- IF:MEDICAID_BOX -->
Now, I have to ask, have you lost or been denied Medicaid in the
last 90 days?
<!-- ENDIF -->

<!-- IF:INCOME_LOW -->
> COACHING: IMMEDIATELY MOVE TO BALANCE CARE PITCH!!!!!
<!-- ENDIF -->
```

### 4.4 Practice Mode (P1 — Important)

#### 4.4.1 Rehearsal Features
- Full teleprompter experience without being on a live call
- Speech recognition tracks the agent's practice reading
- Ability to replay/restart any section
- No connection to CRM or customer data required
- Accessible from a "Practice" button in the main app window

### 4.5 Settings & Customization (P1 — Important)

#### 4.5.1 Configurable Options
Inherit from Textream's settings architecture:

| Setting | Options |
|---------|---------|
| Font family | Sans-serif, Serif, Monospace, OpenDyslexic |
| Font size | Small, Medium, Large, Extra Large |
| Accent/highlight color | 6+ preset colors |
| Scroll speed (fallback) | Adjustable WPM for classic mode |
| Window opacity | Slider from 50% to 100% |
| Window dimensions | Adjustable width and height |
| Glass/blur effect | Toggle on/off |

#### 4.5.2 Fallback Scroll Mode
If speech recognition fails or microphone is unavailable:
- Automatically fall back to classic auto-scroll mode
- Agent can manually adjust speed with hotkeys
- Visual indicator showing which mode is active

## 5. Technical Architecture

### 5.1 Foundation: Textream Fork

ScriptFlow is built by adapting the Textream codebase:

| Textream Component | ScriptFlow Adaptation |
|--------------------|----------------------|
| `TextreamApp.swift` | → `ScriptFlowApp.swift` — Entry point, branding |
| `ContentView.swift` | → Redesigned for script loading UI + practice mode |
| `SpeechRecognizer.swift` | → Reused largely as-is (on-device speech matching) |
| `NotchOverlayController.swift` | → Adapted for floating window mode + phase bar |
| `MarqueeTextView.swift` | → Extended for coaching cues, placeholders, conditionals |
| `NotchSettings.swift` | → Extended with ScriptFlow-specific settings |
| `SettingsView.swift` | → Simplified and rebranded |
| *(new)* `ScriptParser.swift` | Parses Markdown/JSON script files into structured data |
| *(new)* `ScriptPhase.swift` | Data model for script phases, branches, cues |
| *(new)* `PhaseBarView.swift` | Phase progress bar UI component |
| *(new)* `BranchManager.swift` | Manages conditional branch state (highlighted/dimmed) |

### 5.2 System Requirements
- macOS 15 Sequoia or later (matches Textream)
- Microphone access (for speech recognition)
- No internet required (fully offline operation)

### 5.3 Data Flow

```
Script File (Markdown/JSON)
    ↓ ScriptParser
Structured Script Model (phases, blocks, branches, cues)
    ↓ ContentView
Teleprompter Overlay (MarqueeTextView + PhaseBarView)
    ↓ SpeechRecognizer
Word-by-word highlighting + auto-scroll
    ↓ BranchManager
Conditional branch highlighting based on agent input
```

### 5.4 Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Swift + SwiftUI | Matches Textream; native macOS performance |
| Speech recognition | Apple Speech Framework (on-device) | No cloud dependency, no privacy concerns, no latency |
| Script format | Markdown with custom extensions | Easy for non-developers to edit; familiar format |
| Distribution | Direct DMG sharing | Simplest for <20 users; no App Store overhead |
| Settings persistence | UserDefaults | Proven pattern from Textream; simple and reliable |
| Script hot-reload | FSEvents file watcher | Detects script file changes and reloads without restart |

## 6. Non-Functional Requirements

### 6.1 Performance
- Overlay must render at 60 FPS with no jank
- Speech recognition latency < 500ms word-to-highlight
- App memory footprint < 150MB
- App launch to ready state < 3 seconds

### 6.2 Privacy & Compliance
- All speech recognition processed on-device via Apple's Speech Framework
- No audio data transmitted over the network
- No customer data entered into or stored by the app
- No analytics or telemetry collected

### 6.3 Reliability
- Graceful fallback to classic auto-scroll if speech recognition fails
- Automatic microphone reconnection on device switch (e.g., AirPods → USB headset)
- Window position/size restored on app restart
- Script file validation with clear error messages for malformed files

## 7. Out of Scope (v1.0)

- Web or mobile version
- Multi-user / admin dashboard
- CRM integration
- Customer data pre-population
- Call recording or analytics
- Remote script syncing (cloud-based)
- Fill-in-the-blank data entry (fields are visual placeholders only)

## 8. Success Metrics

| Metric | Target |
|--------|--------|
| Agent adoption | >80% of team using ScriptFlow within 2 weeks of launch |
| Script compliance | Reduction in missed disclosures/consent steps (qualitative feedback) |
| New agent ramp time | Agents comfortable with script flow within 3 practice sessions |
| Agent satisfaction | Positive feedback from >75% of agents in informal survey |

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Speech recognition accuracy in noisy call center | Word tracking falls behind or jumps | Implement fallback to auto-scroll; tune fuzzy matching thresholds |
| Agents distracted by teleprompter instead of listening to customer | Worse call quality | Keep overlay compact; coaching cues encourage active listening |
| Script file format too complex for non-technical editors | Updates bottlenecked | Provide clear documentation + a template file; consider a simple editor tool later |
| macOS Sequoia requirement excludes agents on older machines | Some agents can't use it | Verify team's macOS versions before development; consider Sonoma support |
| Microphone conflict with VoIP/softphone app | Speech recognition can't access mic | Test with common VoIP tools (RingCentral, Dialpad, etc.); use shared audio input |

## 10. Milestones

| Phase | Scope | Estimate |
|-------|-------|----------|
| **M1: Foundation** | Fork Textream, rebrand to ScriptFlow, floating window mode, basic script loading from Markdown | Sprint 1 |
| **M2: Script Engine** | Script parser, phase model, coaching cues rendering, placeholder styling, phase progress bar | Sprint 2 |
| **M3: Branch System** | Conditional branch rendering, highlight/dim states, branch toggle controls | Sprint 3 |
| **M4: Polish & Practice** | Practice mode, global hotkeys, settings UI, fallback scroll mode, edge case handling | Sprint 4 |
| **M5: Distribution** | DMG build, team distribution, onboarding guide, initial script file creation | Sprint 5 |

## Appendix A: ACA Script Structure Analysis

The current script (Script 2.0) contains:

- **8 distinct phases** across 9 pages
- **~15 conditional branches** (IF MEDICAID, IF INCOME LOW, IF FEMALE, IF MALE, IF SECURITY, IF PROTECT, IF FAMILY, IF SELF EMPLOYED, IF RESIDENT, IF LOST COVERAGE, etc.)
- **~20 fill-in placeholders** (customer name, agent name, state, zip code, subsidy amount, copay amounts, deductible, coinsurance %, carrier name, plan name, prices, dates, member ID, etc.)
- **~12 coaching cues** (DON'T PAUSE, CONTINUE NO PAUSING, UNLOAD YOUR AMMUNITION, BRING UP THEIR PAINS, GATHER CARD INFO, etc.)
- **3 form-sending steps** (ACA Consent, CareConnect Verification, UCA Verification)
- **1 mandatory verbal disclosure sequence** (page 7 — agent reads identity/plan/consent confirmations)

## Appendix B: Textream Components Reference

Source: [github.com/f/textream](https://github.com/f/textream)

| File | Lines | Reuse Strategy |
|------|-------|---------------|
| `SpeechRecognizer.swift` | ~500 | Heavy reuse — core speech-to-text engine, fuzzy matching |
| `MarqueeTextView.swift` | ~550 | Fork & extend — add coaching cue, placeholder, and branch rendering |
| `NotchOverlayController.swift` | ~1100 | Fork — strip notch mode, keep floating window mode |
| `NotchSettings.swift` | ~350 | Fork & extend — add ScriptFlow-specific settings |
| `ContentView.swift` | ~250 | Rewrite — new UI for script loading, practice mode, phase navigation |
| `SettingsView.swift` | ~1100 | Simplify — remove external display, add script-specific settings |
| `TextreamApp.swift` | ~90 | Rebrand — entry point, rename, update window management |
| `ExternalDisplayController.swift` | ~280 | Remove — not needed for ScriptFlow v1 |
| `UpdateChecker.swift` | ~110 | Remove or adapt — not distributing via GitHub releases |
