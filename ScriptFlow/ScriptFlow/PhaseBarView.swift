//
//  PhaseBarView.swift
//  ScriptFlow
//
//  Compact segmented progress bar showing script phases.
//  Each segment is proportionally sized by speakable content.
//

import SwiftUI

struct PhaseBarView: View {
    let taggedWords: [TaggedWord]
    let highlightedSpeakableCharCount: Int
    let speakableCharsPerPhase: [Int]
    var onPhaseSelected: ((Int) -> Void)?

    private var phaseCount: Int {
        speakableCharsPerPhase.count
    }

    /// Extract phase titles from phaseHeader tagged words
    private var phaseTitles: [String] {
        var titles: [String] = []
        for tw in taggedWords {
            if tw.type == .phaseHeader {
                // Strip "--- TITLE ---" formatting
                let raw = tw.word
                    .replacingOccurrences(of: "---", with: "")
                    .trimmingCharacters(in: .whitespaces)
                titles.append(abbreviate(raw))
            }
        }
        // Pad if needed
        while titles.count < phaseCount {
            titles.append("Phase \(titles.count + 1)")
        }
        return titles
    }

    /// Current phase: the phase containing the current highlight position
    private var currentPhaseIndex: Int {
        guard phaseCount > 0 else { return 0 }
        var cumulative = 0
        for (i, count) in speakableCharsPerPhase.enumerated() {
            cumulative += count
            if highlightedSpeakableCharCount < cumulative {
                return i
            }
        }
        return phaseCount - 1
    }

    private var totalSpeakableChars: Int {
        speakableCharsPerPhase.reduce(0, +)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<phaseCount, id: \.self) { index in
                phaseSegment(index: index)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func phaseSegment(index: Int) -> some View {
        let isActive = index == currentPhaseIndex
        let isPassed = index < currentPhaseIndex
        let title = index < phaseTitles.count ? phaseTitles[index] : ""
        let proportion = totalSpeakableChars > 0
            ? CGFloat(speakableCharsPerPhase[index]) / CGFloat(totalSpeakableChars)
            : CGFloat(1.0 / Double(phaseCount))

        Button {
            onPhaseSelected?(index)
        } label: {
            VStack(spacing: 2) {
                // Bar segment
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(isActive: isActive, isPassed: isPassed))
                    .frame(height: 4)

                // Label
                Text(title)
                    .font(.system(size: 8, weight: isActive ? .bold : .medium))
                    .foregroundStyle(labelColor(isActive: isActive, isPassed: isPassed))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 0, maxWidth: .infinity)
        .layoutPriority(Double(proportion))
    }

    private func barColor(isActive: Bool, isPassed: Bool) -> Color {
        if isActive {
            return Color.yellow
        } else if isPassed {
            return Color.white.opacity(0.3)
        } else {
            return Color.white.opacity(0.1)
        }
    }

    private func labelColor(isActive: Bool, isPassed: Bool) -> Color {
        if isActive {
            return Color.white.opacity(0.9)
        } else if isPassed {
            return Color.white.opacity(0.4)
        } else {
            return Color.white.opacity(0.25)
        }
    }

    /// Abbreviate long phase titles to fit in compact bar
    private func abbreviate(_ title: String) -> String {
        // Already short enough
        if title.count <= 10 { return title }
        // Take first word or abbreviate
        let words = title.split(separator: " ")
        if words.count == 1 {
            return String(title.prefix(8)) + ".."
        }
        // Use initials for long multi-word titles, keep first word
        if title.count > 16 {
            return String(words.first ?? "") + " " + words.dropFirst().map { String($0.prefix(1)) }.joined()
        }
        return title
    }
}
