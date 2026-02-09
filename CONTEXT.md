# ScriptFlow — Context & Domain Knowledge

## Company

**First Health Enrollment (FHE)** is an insurance brokerage that helps consumers enroll in ACA (Affordable Care Act) marketplace health insurance plans. Licensed agents conduct phone calls with prospective customers who have submitted online applications for Obamacare coverage.

## Domain Glossary

| Term | Definition |
|------|-----------|
| **ACA** | Affordable Care Act — federal law that established health insurance marketplaces |
| **Marketplace** | Healthcare.gov and state exchanges where consumers shop for ACA plans |
| **SEP** | Special Enrollment Period — window to enroll outside Open Enrollment (e.g., loss of coverage) |
| **Subsidy / Tax Credit** | Federal financial assistance that reduces monthly premium cost based on income |
| **Sherpa** | Quoting tool agents use to look up marketplace plans and subsidies |
| **CareConnect** | Third-party provider of supplemental dental, vision, and accidental benefits |
| **UCA** | United Consumer Association — membership organization for CareConnect benefits |
| **Binder Payment** | First premium payment that activates the insurance policy |
| **Carrier** | The insurance company providing the major medical plan (e.g., BCBS, Ambetter) |
| **Agent of Record** | The licensed agent authorized to manage a consumer's marketplace application |
| **USCIS / Alien Number** | Immigration identification number for legal residents |
| **Coinsurance** | Percentage of costs the consumer pays after meeting their deductible |
| **Deductible** | Amount consumer pays out-of-pocket before insurance begins covering costs |
| **Copay** | Fixed dollar amount for a specific service (e.g., $25 doctor visit) |
| **Balance Care** | Alternative product pitched when consumer income is too low for ACA subsidy |
| **MediAssist** | Lower-tier plan variant with $15K accidental death benefit (vs. $200K standard) |
| **Security / Protect** | Plan add-on variants with critical illness or accidental medical expense benefits |

## The ACA Sales Call Flow

1. **Inbound lead** — Customer submits online application for Obamacare
2. **Agent calls back** — Licensed agent responds to the application
3. **Qualification** — Agent collects demographic/income data to determine subsidy eligibility
4. **Medical needs assessment** — Pre-existing conditions, prescriptions, doctor preferences
5. **Plan presentation** — Agent presents recommended plan with benefits tailored to customer needs
6. **Close** — Agent collects payment information and personal details (SSN, address)
7. **Consent & verification** — Agent sends enrollment consent form and CareConnect verification
8. **Verbal disclosures** — Agent reads mandatory compliance disclosures
9. **Handoff** — Agent transfers customer to Verification Department

## Technical Foundation

**Textream** (https://github.com/f/textream) — Open-source macOS teleprompter app built in Swift/SwiftUI. ScriptFlow is adapted from this codebase. Key capabilities inherited:

- On-device speech recognition via Apple's Speech Framework
- Fuzzy word matching for speech-to-text alignment
- Floating window overlay with always-on-top rendering
- Smooth word-by-word highlighting and auto-scroll
- Settings persistence via UserDefaults
- macOS 15 Sequoia+ requirement

## Agent Workspace

During calls, agents typically have open:
- **Softphone / VoIP** — for the customer call
- **Sherpa** — marketplace quoting tool
- **CRM** — customer relationship management system
- **Browser** — Healthcare.gov, carrier portals
- **ScriptFlow** — floating overlay on top of these apps
