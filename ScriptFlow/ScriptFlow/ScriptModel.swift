//
//  ScriptModel.swift
//  ScriptFlow
//
//  Data models for the structured sales script.
//

import Foundation
import SwiftUI

/// Style constants for each word type in the teleprompter
enum ScriptStyle {
    static let coachingColor = Color(red: 1.0, green: 0.45, blue: 0.4)   // coral
    static let placeholderColor = Color(red: 1.0, green: 0.82, blue: 0.28) // gold
    static let branchColor = Color(red: 0.4, green: 0.85, blue: 1.0)      // cyan
    static let headerColor = Color.white.opacity(0.5)                      // dimmed white
}

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

    /// Total character count of speakable text (for progress calculations)
    var totalSpeakableCharCount: Int {
        speakableText.count
    }

    /// Speakable character count per phase (for PhaseBarView proportional sizing)
    var speakableCharsPerPhase: [Int] {
        var counts = Array(repeating: 0, count: phases.count)
        for tw in taggedWords {
            if tw.speakableCharOffset >= 0 {
                counts[tw.phaseIndex] += tw.word.count + 1 // +1 for space separator
            }
        }
        return counts
    }

    /// All words for the teleprompter display, tagged with their type and speakable offset
    var taggedWords: [TaggedWord] {
        var words: [TaggedWord] = []
        var speakableOffset = 0
        for (phaseIndex, phase) in phases.enumerated() {
            // Phase header as a single display word
            let headerText = "--- \(phase.title.uppercased()) ---"
            words.append(TaggedWord(word: headerText, type: .phaseHeader, speakableCharOffset: -1, phaseIndex: phaseIndex, branchCondition: nil))
            collectTaggedWords(blocks: phase.blocks, words: &words, speakableOffset: &speakableOffset, phaseIndex: phaseIndex, branchCondition: nil)
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

    private func collectTaggedWords(blocks: [ScriptBlock], words: inout [TaggedWord], speakableOffset: inout Int, phaseIndex: Int, branchCondition: String?) {
        for block in blocks {
            switch block {
            case .speakable(_, let text):
                let splitWords = text.split(whereSeparator: \.isWhitespace).map(String.init)
                for word in splitWords {
                    words.append(TaggedWord(word: word, type: .speakable, speakableCharOffset: speakableOffset, phaseIndex: phaseIndex, branchCondition: branchCondition))
                    speakableOffset += word.count + 1 // +1 for space
                }
            case .coaching(_, let text):
                let splitWords = text.split(whereSeparator: \.isWhitespace).map(String.init)
                for word in splitWords {
                    words.append(TaggedWord(word: word, type: .coaching, speakableCharOffset: -1, phaseIndex: phaseIndex, branchCondition: branchCondition))
                }
            case .placeholder(_, let label, _):
                let word = "[\(label)]"
                words.append(TaggedWord(word: word, type: .placeholder, speakableCharOffset: -1, phaseIndex: phaseIndex, branchCondition: branchCondition))
            case .branch(_, let condition, let subBlocks):
                // Branch label is a control — nil branchCondition so it's never dimmed
                let condWord = "IF: \(condition)"
                words.append(TaggedWord(word: condWord, type: .branchLabel, speakableCharOffset: -1, phaseIndex: phaseIndex, branchCondition: nil))
                collectTaggedWords(blocks: subBlocks, words: &words, speakableOffset: &speakableOffset, phaseIndex: phaseIndex, branchCondition: condition)
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
    /// Character offset in speakable-only text. -1 for non-speakable words.
    let speakableCharOffset: Int
    let phaseIndex: Int
    /// The branch condition this word belongs to (nil = top-level, not inside any branch).
    let branchCondition: String?
}

enum WordType {
    case speakable
    case coaching
    case placeholder
    case branchLabel
    case phaseHeader
}
