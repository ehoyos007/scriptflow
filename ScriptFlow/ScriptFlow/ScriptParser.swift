//
//  ScriptParser.swift
//  ScriptFlow
//
//  Parses Markdown-formatted script files into structured Script models.
//

import Foundation

struct ScriptParser {

    /// Parse a Markdown script file into a Script model
    static func parse(markdown: String) -> Script {
        let lines = markdown.components(separatedBy: "\n")
        var title = "Script"
        var version = "1.0"
        var phases: [ScriptPhase] = []
        var currentPhaseTitle: String?
        var currentBlocks: [ScriptBlock] = []
        var inFrontMatter = false
        var frontMatterDone = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Front matter parsing (--- delimited)
            if trimmed == "---" {
                if !frontMatterDone {
                    inFrontMatter.toggle()
                    if !inFrontMatter { frontMatterDone = true }
                }
                continue
            }
            if inFrontMatter {
                if let value = extractFrontMatter(key: "title", from: trimmed) {
                    title = value
                } else if let value = extractFrontMatter(key: "version", from: trimmed) {
                    version = value
                }
                continue
            }

            // Phase headers (## Header)
            if trimmed.hasPrefix("## ") {
                // Save previous phase
                if let phaseTitle = currentPhaseTitle, !currentBlocks.isEmpty {
                    phases.append(ScriptPhase(title: phaseTitle, blocks: currentBlocks))
                }
                currentPhaseTitle = String(trimmed.dropFirst(3))
                currentBlocks = []
                continue
            }

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Coaching cues (> COACHING: ...)
            if trimmed.hasPrefix("> ") {
                let cueText = String(trimmed.dropFirst(2))
                    .replacingOccurrences(of: "COACHING:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !cueText.isEmpty {
                    currentBlocks.append(.coaching(text: cueText))
                }
                continue
            }

            // Conditional branches (<!-- IF:CONDITION --> ... <!-- ENDIF -->)
            if trimmed.hasPrefix("<!-- IF:") {
                let condition = trimmed
                    .replacingOccurrences(of: "<!-- IF:", with: "")
                    .replacingOccurrences(of: "-->", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // For now, treat the next block as a branch
                currentBlocks.append(.branch(condition: condition, blocks: []))
                continue
            }
            if trimmed == "<!-- ENDIF -->" {
                continue
            }

            // Regular speakable text — check for inline placeholders
            let processed = processInlinePlaceholders(trimmed)
            for block in processed {
                // If last block is a branch with empty content, append to it
                if case .branch(let id, let condition, var subBlocks) = currentBlocks.last, subBlocks.isEmpty {
                    currentBlocks.removeLast()
                    subBlocks.append(block)
                    currentBlocks.append(.branch(id: id, condition: condition, blocks: subBlocks))
                } else if case .branch(let id, let condition, var subBlocks) = currentBlocks.last {
                    // Continue appending to the current branch until we hit ENDIF
                    currentBlocks.removeLast()
                    subBlocks.append(block)
                    currentBlocks.append(.branch(id: id, condition: condition, blocks: subBlocks))
                } else {
                    currentBlocks.append(block)
                }
            }
        }

        // Save final phase
        if let phaseTitle = currentPhaseTitle {
            if !currentBlocks.isEmpty {
                phases.append(ScriptPhase(title: phaseTitle, blocks: currentBlocks))
            }
        } else if !currentBlocks.isEmpty {
            // No phases defined — wrap everything in a single phase
            phases.append(ScriptPhase(title: "Script", blocks: currentBlocks))
        }

        return Script(title: title, version: version, phases: phases)
    }

    /// Load and parse a script from a file path
    static func load(from path: String) -> Script? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return parse(markdown: content)
    }

    // MARK: - Private helpers

    private static func extractFrontMatter(key: String, from line: String) -> String? {
        if line.lowercased().hasPrefix("\(key):") {
            let value = line.dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return value
        }
        return nil
    }

    /// Process a line of text and extract inline [PLACEHOLDER] markers
    private static func processInlinePlaceholders(_ text: String) -> [ScriptBlock] {
        // Simple approach: entire line is speakable text
        // Placeholders like [CUSTOMER NAME] are rendered distinctly by the view layer
        return [.speakable(text: text)]
    }
}
