//
//  ScriptModel.swift
//  ScriptFlow
//
//  Data models for the structured sales script.
//

import Foundation

/// A single block of content within a script phase
enum ScriptBlock: Identifiable {
    case speakable(id: UUID = UUID(), text: String)
    case coaching(id: UUID = UUID(), text: String)
    case placeholder(id: UUID = UUID(), label: String, context: String)
    case branch(id: UUID = UUID(), condition: String, blocks: [ScriptBlock])
    case divider(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .speakable(let id, _): return id
        case .coaching(let id, _): return id
        case .placeholder(let id, _, _): return id
        case .branch(let id, _, _): return id
        case .divider(let id): return id
        }
    }
}

/// A phase/section of the script
struct ScriptPhase: Identifiable {
    let id: UUID
    let title: String
    let blocks: [ScriptBlock]

    init(title: String, blocks: [ScriptBlock]) {
        self.id = UUID()
        self.title = title
        self.blocks = blocks
    }
}

/// The complete parsed script
struct Script {
    let title: String
    let version: String
    let phases: [ScriptPhase]

    /// Flattened speakable text for the speech recognizer (excludes coaching cues)
    var speakableText: String {
        var parts: [String] = []
        for phase in phases {
            collectSpeakable(blocks: phase.blocks, into: &parts)
        }
        return parts.joined(separator: " ")
    }

    /// All words for the teleprompter display, tagged with their type
    var taggedWords: [TaggedWord] {
        var words: [TaggedWord] = []
        var charOffset = 0
        for (phaseIndex, phase) in phases.enumerated() {
            // Add phase header
            let headerText = "--- \(phase.title.uppercased()) ---"
            for word in headerText.split(separator: " ").map(String.init) {
                words.append(TaggedWord(word: word, type: .phaseHeader, charOffset: charOffset, phaseIndex: phaseIndex))
                charOffset += word.count + 1
            }
            collectTaggedWords(blocks: phase.blocks, words: &words, charOffset: &charOffset, phaseIndex: phaseIndex)
        }
        return words
    }

    private func collectSpeakable(blocks: [ScriptBlock], into parts: inout [String]) {
        for block in blocks {
            switch block {
            case .speakable(_, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { parts.append(trimmed) }
            case .branch(_, _, let subBlocks):
                collectSpeakable(blocks: subBlocks, into: &parts)
            case .coaching, .placeholder, .divider:
                break
            }
        }
    }

    private func collectTaggedWords(blocks: [ScriptBlock], words: inout [TaggedWord], charOffset: inout Int, phaseIndex: Int) {
        for block in blocks {
            switch block {
            case .speakable(_, let text):
                for word in text.split(separator: " ").map(String.init) {
                    words.append(TaggedWord(word: word, type: .speakable, charOffset: charOffset, phaseIndex: phaseIndex))
                    charOffset += word.count + 1
                }
            case .coaching(_, let text):
                for word in text.split(separator: " ").map(String.init) {
                    words.append(TaggedWord(word: word, type: .coaching, charOffset: charOffset, phaseIndex: phaseIndex))
                    charOffset += word.count + 1
                }
            case .placeholder(_, let label, _):
                let word = "[\(label)]"
                words.append(TaggedWord(word: word, type: .placeholder, charOffset: charOffset, phaseIndex: phaseIndex))
                charOffset += word.count + 1
            case .branch(_, let condition, let subBlocks):
                let condWord = "IF: \(condition)"
                for word in condWord.split(separator: " ").map(String.init) {
                    words.append(TaggedWord(word: word, type: .branchLabel, charOffset: charOffset, phaseIndex: phaseIndex))
                    charOffset += word.count + 1
                }
                collectTaggedWords(blocks: subBlocks, words: &words, charOffset: &charOffset, phaseIndex: phaseIndex)
            case .divider:
                break
            }
        }
    }
}

/// A word with its semantic type for rendering
struct TaggedWord: Identifiable {
    let id = UUID()
    let word: String
    let type: WordType
    let charOffset: Int
    let phaseIndex: Int
}

enum WordType {
    case speakable
    case coaching
    case placeholder
    case branchLabel
    case phaseHeader
}
