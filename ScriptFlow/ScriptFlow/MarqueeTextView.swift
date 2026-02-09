//
//  MarqueeTextView.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import SwiftUI

// MARK: - Data

struct WordItem: Identifiable {
    let id: Int
    let word: String
    let wordType: WordType
    let speakableCharOffset: Int // -1 for non-speakable
    /// The speakableCharOffset + word.count of the last speakable word *before* this one.
    /// Used to determine when non-speakable words have been "passed" by the highlight.
    let prevSpeakableEnd: Int
    /// Branch condition this word belongs to (nil = top-level).
    let branchCondition: String?
}

// MARK: - Preference key to report word Y positions

struct WordYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Teleprompter

struct SpeechScrollView: View {
    let taggedWords: [TaggedWord]
    let totalSpeakableCharCount: Int
    let highlightedSpeakableCharCount: Int
    var font: NSFont = .systemFont(ofSize: 18, weight: .semibold)
    var highlightColor: Color = .white
    var branchManager: BranchManager? = nil
    var onWordTap: ((Int) -> Void)? = nil
    var onManualScroll: ((Bool, Double) -> Void)? = nil
    var smoothScroll: Bool = false
    var smoothWordProgress: Double = 0

    var isListening: Bool = true
    @State private var scrollOffset: CGFloat = 0
    @State private var manualOffset: CGFloat = 0
    @State private var wordYPositions: [Int: CGFloat] = [:]
    @State private var containerHeight: CGFloat = 0
    @State private var isUserScrolling: Bool = false

    /// Convenience: plain word strings for scroll calculations
    private var words: [String] {
        taggedWords.map(\.word)
    }

    var body: some View {
        GeometryReader { geo in
            WordFlowLayout(
                taggedWords: taggedWords,
                totalSpeakableCharCount: totalSpeakableCharCount,
                highlightedSpeakableCharCount: highlightedSpeakableCharCount,
                font: font,
                highlightColor: highlightColor,
                branchManager: branchManager,
                highlightWords: !smoothScroll,
                containerWidth: geo.size.width,
                onWordTap: { speakableCharOffset in
                    manualOffset = 0
                    onWordTap?(speakableCharOffset)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        recalcCenter(containerHeight: containerHeight)
                    }
                }
            )
            .onPreferenceChange(WordYPreferenceKey.self) { positions in
                wordYPositions = positions
            }
            .offset(y: scrollOffset + manualOffset)
            .animation(smoothScroll ? .linear(duration: 0.06) : .easeOut(duration: 0.5), value: scrollOffset)
            .animation(.easeOut(duration: 0.15), value: manualOffset)
            .onChange(of: geo.size.height) { _, newHeight in
                containerHeight = newHeight
                if isListening {
                    recalcCenter(containerHeight: newHeight)
                }
            }
            .onChange(of: highlightedSpeakableCharCount) { _, _ in
                if isListening && !smoothScroll {
                    manualOffset = 0
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .onChange(of: smoothWordProgress) { _, _ in
                if isListening && smoothScroll {
                    manualOffset = 0
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .onChange(of: isListening) { _, listening in
                if listening {
                    manualOffset = 0
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .onAppear {
                containerHeight = geo.size.height
            }
            .overlay(
                ScrollWheelView(
                    onScroll: { delta in
                        let canScroll = smoothScroll ? isListening : !isListening
                        guard canScroll else { return }

                        if smoothScroll && !isUserScrolling {
                            isUserScrolling = true
                            onManualScroll?(true, 0)
                        }

                        let maxY = wordYPositions.values.max() ?? 0
                        let containerHeight = geo.size.height
                        let maxUp = containerHeight * 0.5
                        let maxDown = max(0, maxY - containerHeight * 0.5)

                        let newOffset = manualOffset + delta
                        let upperBound = maxUp
                        let lowerBound = -maxDown

                        if newOffset > upperBound {
                            let over = newOffset - upperBound
                            manualOffset = upperBound + over * 0.2
                        } else if newOffset < lowerBound {
                            let over = lowerBound - newOffset
                            manualOffset = lowerBound - over * 0.2
                        } else {
                            manualOffset = newOffset
                        }
                    },
                    onScrollEnd: {
                        if smoothScroll && isUserScrolling {
                            let newProgress = wordProgressAtCurrentOffset()
                            withAnimation(.easeOut(duration: 0.15)) {
                                manualOffset = 0
                            }
                            isUserScrolling = false
                            onManualScroll?(false, newProgress)
                        } else {
                            let maxY = wordYPositions.values.max() ?? 0
                            let containerHeight = geo.size.height
                            let upperBound = containerHeight * 0.5
                            let lowerBound = -max(0, maxY - containerHeight * 0.5)

                            if manualOffset > upperBound || manualOffset < lowerBound {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    manualOffset = min(upperBound, max(lowerBound, manualOffset))
                                }
                            }
                        }
                    }
                )
            )
        }
        .clipped()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.05),
                    .init(color: .white, location: 0.95),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func recalcCenter(containerHeight: CGFloat) {
        let center = containerHeight * 0.5

        if smoothScroll {
            let wordIdx = Int(smoothWordProgress)
            let fraction = smoothWordProgress - Double(wordIdx)
            let clampedIdx = max(0, min(wordIdx, words.count - 1))
            guard let wordY = wordYPositions[clampedIdx] else { return }
            let nextY = wordYPositions[clampedIdx + 1] ?? wordY
            let interpolatedY = wordY + (nextY - wordY) * CGFloat(fraction)
            scrollOffset = center - interpolatedY
        } else {
            let wordIdx = activeDisplayWordIndex()
            if let wordY = wordYPositions[wordIdx] {
                let target = center - wordY
                if abs(scrollOffset - target) > 1 {
                    scrollOffset = target
                }
            }
        }
    }

    private func wordProgressAtCurrentOffset() -> Double {
        let center = containerHeight * 0.5
        let targetY = center - (scrollOffset + manualOffset)

        let sorted = wordYPositions.sorted { $0.key < $1.key }
        guard !sorted.isEmpty else { return smoothWordProgress }

        for i in 0..<sorted.count {
            let (wordIdx, wordY) = sorted[i]
            if i + 1 < sorted.count {
                let (_, nextY) = sorted[i + 1]
                if targetY >= wordY && targetY <= nextY {
                    let frac = (nextY - wordY) > 0 ? Double(targetY - wordY) / Double(nextY - wordY) : 0
                    return Double(wordIdx) + frac
                }
            } else if targetY >= wordY {
                return Double(wordIdx)
            }
        }
        if targetY < (sorted.first?.value ?? 0) {
            return 0
        }
        return Double(words.count)
    }

    /// Map highlighted speakable char count → display word index (for scroll centering)
    private func activeDisplayWordIndex() -> Int {
        for (i, tw) in taggedWords.enumerated() {
            guard tw.speakableCharOffset >= 0 else { continue }
            let end = tw.speakableCharOffset + tw.word.count
            if highlightedSpeakableCharCount <= end { return i }
        }
        return max(0, taggedWords.count - 1)
    }
}

// MARK: - Word Flow Layout

struct WordFlowLayout: View {
    let taggedWords: [TaggedWord]
    let totalSpeakableCharCount: Int
    let highlightedSpeakableCharCount: Int
    let font: NSFont
    var highlightColor: Color = .white
    var branchManager: BranchManager? = nil
    var highlightWords: Bool = true
    let containerWidth: CGFloat
    var onWordTap: ((Int) -> Void)? = nil

    private func nextSpeakableWordIndex(items: [WordItem]) -> Int {
        for item in items {
            guard item.wordType == .speakable, item.speakableCharOffset >= 0 else { continue }
            let charsIntoWord = highlightedSpeakableCharCount - item.speakableCharOffset
            let litCount = max(0, min(item.word.count, charsIntoWord))
            let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
            if litCount < letterCount {
                return item.id
            }
        }
        return -1
    }

    var body: some View {
        let items = buildItems()
        let lines = buildLines(items: items)
        let nextIdx = nextSpeakableWordIndex(items: items)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                // Check if this is a centered line (header or branch)
                let isCentered = line.count == 1 && (line[0].wordType == .phaseHeader || line[0].wordType == .branchLabel)
                HStack(spacing: 0) {
                    if isCentered { Spacer() }
                    ForEach(line, id: \.id) { item in
                        wordView(for: item, isNextWord: item.id == nextIdx)
                            .id(item.id)
                    }
                    if isCentered { Spacer() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: "flowLayout")
    }

    private func wordView(for item: WordItem, isNextWord: Bool) -> some View {
        let isPassed: Bool = {
            if item.wordType == .speakable {
                let charsInto = highlightedSpeakableCharCount - item.speakableCharOffset
                let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
                return max(0, min(item.word.count, charsInto)) >= letterCount
            } else {
                return highlightedSpeakableCharCount >= item.prevSpeakableEnd && item.prevSpeakableEnd > 0
            }
        }()

        let dimOpacity = branchManager?.opacity(for: item.branchCondition) ?? 1.0

        return Group {
            switch item.wordType {
            case .phaseHeader:
                phaseHeaderView(item: item, isPassed: isPassed)
            case .branchLabel:
                branchLabelView(item: item, isPassed: isPassed)
            case .coaching:
                coachingView(item: item, isPassed: isPassed)
                    .opacity(dimOpacity)
            case .placeholder:
                placeholderView(item: item, isPassed: isPassed)
                    .opacity(dimOpacity)
            case .speakable:
                speakableView(item: item, isNextWord: isNextWord, isPassed: isPassed)
                    .opacity(dimOpacity)
            }
        }
        .background(
            GeometryReader { wordGeo in
                Color.clear.preference(
                    key: WordYPreferenceKey.self,
                    value: [item.id: wordGeo.frame(in: .named("flowLayout")).midY]
                )
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if item.speakableCharOffset >= 0 {
                onWordTap?(item.speakableCharOffset)
            }
        }
    }

    // MARK: - Word type views

    private func speakableView(item: WordItem, isNextWord: Bool, isPassed: Bool) -> some View {
        let wordLen = item.word.count
        let charsIntoWord = highlightedSpeakableCharCount - item.speakableCharOffset
        let litCount = max(0, min(wordLen, charsIntoWord))
        let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
        let isFullyLit = litCount >= letterCount
        let isCurrentWord = isNextWord || (charsIntoWord >= 0 && !isFullyLit)

        if !highlightWords {
            let uniformColor = highlightColor
            return Text(item.word + " ")
                .font(Font(font))
                .foregroundStyle(uniformColor)
        }

        let dimColor: Color = isCurrentWord
            ? highlightColor.opacity(0.6)
            : highlightColor

        let wordColor: Color = isFullyLit ? highlightColor.opacity(0.3) : dimColor

        return Text(item.word + " ")
            .font(Font(font))
            .foregroundStyle(wordColor)
            .underline(isCurrentWord, color: wordColor)
    }

    private func coachingView(item: WordItem, isPassed: Bool) -> some View {
        let color = isPassed
            ? ScriptStyle.coachingColor.opacity(0.25)
            : ScriptStyle.coachingColor.opacity(highlightWords ? 0.85 : 0.6)

        return Text(item.word + " ")
            .font(Font(font).italic())
            .foregroundStyle(color)
    }

    private func placeholderView(item: WordItem, isPassed: Bool) -> some View {
        let color = isPassed
            ? ScriptStyle.placeholderColor.opacity(0.25)
            : ScriptStyle.placeholderColor.opacity(highlightWords ? 0.9 : 0.6)

        return Text(item.word + " ")
            .font(Font(font).bold())
            .foregroundStyle(color)
    }

    private func branchLabelView(item: WordItem, isPassed: Bool) -> some View {
        // Extract condition name from "IF: CONDITION" format
        let condition = String(item.word.dropFirst(4)) // drop "IF: "
        let isHighlighted = branchManager?.isHighlighted(condition) ?? false

        let color: Color = {
            if isPassed && !isHighlighted {
                return ScriptStyle.branchColor.opacity(0.3)
            }
            if isHighlighted {
                return ScriptStyle.placeholderColor // yellow/gold when active
            }
            return ScriptStyle.branchColor.opacity(highlightWords ? 0.9 : 0.6)
        }()

        let bgOpacity: Double = isHighlighted ? 0.25 : 0.15

        return Button {
            branchManager?.toggle(condition)
        } label: {
            Text(item.word)
                .font(.system(size: max(10, font.pointSize * 0.75), weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(bgOpacity))
                .clipShape(Capsule())
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func phaseHeaderView(item: WordItem, isPassed: Bool) -> some View {
        let color = isPassed
            ? ScriptStyle.headerColor.opacity(0.3)
            : ScriptStyle.headerColor

        return HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(height: 1)
            Text(item.word.replacingOccurrences(of: "---", with: "").trimmingCharacters(in: .whitespaces))
                .font(.system(size: max(10, font.pointSize * 0.7), weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Build items with prevSpeakableEnd

    private func buildItems() -> [WordItem] {
        var items: [WordItem] = []
        var lastSpeakableEnd = 0

        for (i, tw) in taggedWords.enumerated() {
            let prevEnd = lastSpeakableEnd
            if tw.type == .speakable && tw.speakableCharOffset >= 0 {
                lastSpeakableEnd = tw.speakableCharOffset + tw.word.count
            }
            items.append(WordItem(
                id: i,
                word: tw.word,
                wordType: tw.type,
                speakableCharOffset: tw.speakableCharOffset,
                prevSpeakableEnd: prevEnd,
                branchCondition: tw.branchCondition
            ))
        }
        return items
    }

    private func buildLines(items: [WordItem]) -> [[WordItem]] {
        var lines: [[WordItem]] = [[]]
        var currentLineWidth: CGFloat = 0
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width

        for item in items {
            // Phase headers and branch labels get their own line
            if item.wordType == .phaseHeader || item.wordType == .branchLabel {
                // Start a new line if current line has content
                if !lines[lines.count - 1].isEmpty {
                    lines.append([])
                }
                lines[lines.count - 1].append(item)
                // Force a new line after
                lines.append([])
                currentLineWidth = 0
                continue
            }

            let wordWidth = (item.word as NSString).size(withAttributes: [.font: font]).width + spaceWidth
            if currentLineWidth + wordWidth > containerWidth && !lines[lines.count - 1].isEmpty {
                lines.append([])
                currentLineWidth = 0
            }
            lines[lines.count - 1].append(item)
            currentLineWidth += wordWidth
        }

        // Remove trailing empty line
        if lines.last?.isEmpty == true {
            lines.removeLast()
        }

        return lines
    }
}

// MARK: - Audio Waveform + Progress

struct AudioWaveformProgressView: View {
    let levels: [CGFloat]
    let progress: Double // 0.0 to 1.0

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                let barProgress = Double(index) / Double(max(1, levels.count - 1))
                let isLit = barProgress <= progress

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isLit
                          ? Color.yellow.opacity(0.9)
                          : Color.white.opacity(0.15)
                    )
                    .frame(width: 3, height: max(3, level * 28))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}

// Keep the old one for backward compat
struct AudioWaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        AudioWaveformProgressView(levels: levels, progress: 0)
    }
}

// MARK: - Scroll Wheel Handler

struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    var onScrollEnd: (() -> Void)?

    init(onScroll: @escaping (CGFloat) -> Void, onScrollEnd: (() -> Void)? = nil) {
        self.onScroll = onScroll
        self.onScrollEnd = onScrollEnd
    }

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        view.onScrollEnd = onScrollEnd
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onScrollEnd = onScrollEnd
    }
}

class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var onScrollEnd: (() -> Void)?
    private var scrollMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window else { return event }
                if event.window == window {
                    let delta = event.scrollingDeltaY
                    let scaled = event.hasPreciseScrollingDeltas ? delta : delta * 10
                    self.onScroll?(scaled)

                    if event.phase == .ended || event.momentumPhase == .ended {
                        self.onScrollEnd?()
                    }
                }
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        super.removeFromSuperview()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
