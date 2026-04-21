//
//  NotchOverlayController.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import AppKit
import SwiftUI
import Combine

// MARK: - NSScreen displayID compatibility

extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) ?? 0
    }
}

@Observable
class NotchFrameTracker {
    var visibleHeight: CGFloat = 37 {
        didSet { updatePanel() }
    }
    var visibleWidth: CGFloat = 200 {
        didSet { updatePanel() }
    }
    weak var panel: NSPanel?
    var screenMidX: CGFloat = 0
    var screenMaxY: CGFloat = 0
    var menuBarHeight: CGFloat = 0

    func updatePanel() {
        guard let panel else { return }
        let x = screenMidX - visibleWidth / 2
        let y = screenMaxY - visibleHeight
        panel.setFrame(NSRect(x: x, y: y, width: visibleWidth, height: visibleHeight), display: false)
    }
}

class NotchOverlayController: NSObject {
    private var panel: NSPanel?
    let speechRecognizer = SpeechRecognizer()
    private let branchManager = BranchManager()
    var onComplete: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var isDismissing = false
    private var frameTracker: NotchFrameTracker?
    private var mouseTrackingTimer: AnyCancellable?
    private var cursorTrackingTimer: AnyCancellable?
    private var currentScreenID: UInt32 = 0
    private var statusItem: NSStatusItem?

    func show(taggedWords: [TaggedWord], speakableText: String, totalSpeakableCharCount: Int, speakableCharsPerPhase: [Int] = [], onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.isDismissing = false
        forceClose()
        observeDismiss()

        let settings = NotchSettings.shared

        let screen: NSScreen
        switch settings.notchDisplayMode {
        case .followMouse:
            screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens[0]
        case .fixedDisplay:
            screen = NSScreen.screens.first(where: { $0.displayID == settings.pinnedScreenID }) ?? NSScreen.main ?? NSScreen.screens[0]
        }

        let screenFrame = screen.frame

        if settings.overlayMode == .floating && settings.followCursorWhenUndocked {
            showFollowCursor(taggedWords: taggedWords, totalSpeakableCharCount: totalSpeakableCharCount, speakableCharsPerPhase: speakableCharsPerPhase, settings: settings, screen: screen)
        } else {
            switch settings.overlayMode {
            case .pinned:
                showPinned(taggedWords: taggedWords, totalSpeakableCharCount: totalSpeakableCharCount, speakableCharsPerPhase: speakableCharsPerPhase, settings: settings, screen: screen)
            case .floating:
                showFloating(taggedWords: taggedWords, totalSpeakableCharCount: totalSpeakableCharCount, speakableCharsPerPhase: speakableCharsPerPhase, settings: settings, screenFrame: screenFrame)
            }
        }

        // Word tracking & silence-paused need the microphone; classic does not
        if settings.listeningMode != .classic {
            speechRecognizer.start(with: speakableText)
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
    }

    private func startMouseTracking() {
        mouseTrackingTimer?.cancel()
        mouseTrackingTimer = Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkMouseScreen()
            }
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.cancel()
        mouseTrackingTimer = nil
    }

    private func startCursorTracking() {
        cursorTrackingTimer?.cancel()
        cursorTrackingTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCursorPosition()
            }
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.cancel()
        cursorTrackingTimer = nil
    }

    private func updateCursorPosition() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let cursorOffset: CGFloat = 8
        let x = mouse.x + cursorOffset
        let h = panel.frame.height
        let y = mouse.y - h
        let w = panel.frame.width
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
    }

    private func checkMouseScreen() {
        guard let panel, let frameTracker else { return }
        guard let mouseScreen = screenUnderMouse() else { return }
        let mouseScreenID = mouseScreen.displayID
        guard mouseScreenID != currentScreenID else { return }

        currentScreenID = mouseScreenID
        let screenFrame = mouseScreen.frame

        frameTracker.screenMidX = screenFrame.midX
        frameTracker.screenMaxY = screenFrame.maxY

        let w = frameTracker.visibleWidth
        let h = frameTracker.visibleHeight
        let x = screenFrame.midX - w / 2
        let y = screenFrame.maxY - h
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    private func showPinned(taggedWords: [TaggedWord], totalSpeakableCharCount: Int, speakableCharsPerPhase: [Int], settings: NotchSettings, screen: NSScreen) {
        let notchWidth = settings.notchWidth
        let textAreaHeight = settings.textAreaHeight
        let maxExtraHeight: CGFloat = 350
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        let tracker = NotchFrameTracker()
        tracker.screenMidX = screenFrame.midX
        tracker.screenMaxY = screenFrame.maxY
        tracker.menuBarHeight = menuBarHeight
        tracker.visibleWidth = notchWidth
        tracker.visibleHeight = menuBarHeight + textAreaHeight
        self.frameTracker = tracker
        self.currentScreenID = screen.displayID

        let overlayView = NotchOverlayView(taggedWords: taggedWords, totalSpeakableCharCount: totalSpeakableCharCount, speakableCharsPerPhase: speakableCharsPerPhase, speechRecognizer: speechRecognizer, branchManager: branchManager, menuBarHeight: menuBarHeight, baseTextHeight: textAreaHeight, maxExtraHeight: maxExtraHeight, frameTracker: tracker)
        let contentView = NSHostingView(rootView: overlayView)

        let targetHeight = menuBarHeight + textAreaHeight
        let targetY = screenFrame.maxY - targetHeight
        let xPosition = screenFrame.midX - notchWidth / 2
        let panel = NSPanel(
            contentRect: NSRect(x: xPosition, y: targetY, width: notchWidth, height: targetHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        tracker.panel = panel

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.sharingType = .none
        panel.contentView = contentView

        panel.orderFrontRegardless()
        self.panel = panel

        if settings.notchDisplayMode == .followMouse {
            startMouseTracking()
        }
    }

    private func showFollowCursor(taggedWords: [TaggedWord], totalSpeakableCharCount: Int, speakableCharsPerPhase: [Int], settings: NotchSettings, screen: NSScreen) {
        let panelWidth = settings.notchWidth
        let panelHeight = settings.textAreaHeight

        let mouse = NSEvent.mouseLocation
        let cursorOffset: CGFloat = 8
        let xPosition = mouse.x + cursorOffset
        let yPosition = mouse.y - panelHeight

        let floatingView = FloatingOverlayView(
            taggedWords: taggedWords,
            totalSpeakableCharCount: totalSpeakableCharCount,
            speakableCharsPerPhase: speakableCharsPerPhase,
            speechRecognizer: speechRecognizer,
            branchManager: branchManager,
            baseHeight: panelHeight,
            followingCursor: true
        )
        let contentView = NSHostingView(rootView: floatingView)

        let panel = NSPanel(
            contentRect: NSRect(x: xPosition, y: yPosition, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.contentView = contentView

        panel.orderFrontRegardless()
        self.panel = panel

        startCursorTracking()
        showStatusItem()
    }

    private func showFloating(taggedWords: [TaggedWord], totalSpeakableCharCount: Int, speakableCharsPerPhase: [Int], settings: NotchSettings, screenFrame: CGRect) {
        let panelWidth = settings.notchWidth
        let panelHeight = settings.textAreaHeight

        let xPosition = screenFrame.midX - panelWidth / 2
        let yPosition = screenFrame.midY - panelHeight / 2 + 100

        let floatingView = FloatingOverlayView(
            taggedWords: taggedWords,
            totalSpeakableCharCount: totalSpeakableCharCount,
            speakableCharsPerPhase: speakableCharsPerPhase,
            speechRecognizer: speechRecognizer,
            branchManager: branchManager,
            baseHeight: panelHeight
        )
        let contentView = NSHostingView(rootView: floatingView)

        let panel = NSPanel(
            contentRect: NSRect(x: xPosition, y: yPosition, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.sharingType = .none
        panel.contentView = contentView

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        speechRecognizer.shouldDismiss = true
        speechRecognizer.forceStop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.stopMouseTracking()
            self?.stopCursorTracking()
            self?.removeStatusItem()
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.frameTracker = nil
            self?.speechRecognizer.shouldDismiss = false
            self?.onComplete?()
        }
    }

    private func forceClose() {
        stopMouseTracking()
        stopCursorTracking()
        removeStatusItem()
        cancellables.removeAll()
        speechRecognizer.forceStop()
        branchManager.clearAll()
        panel?.orderOut(nil)
        panel = nil
        frameTracker = nil
        speechRecognizer.shouldDismiss = false
    }

    private func observeDismiss() {
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.speechRecognizer.shouldDismiss, !self.isDismissing else { return }
                self.isDismissing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.stopMouseTracking()
                    self.stopCursorTracking()
                    self.removeStatusItem()
                    self.cancellables.removeAll()
                    self.panel?.orderOut(nil)
                    self.panel = nil
                    self.frameTracker = nil
                    self.speechRecognizer.shouldDismiss = false
                    self.onComplete?()
                }
            }
            .store(in: &cancellables)
    }

    var isShowing: Bool {
        panel != nil
    }

    // MARK: - Status Bar Item (for follow-cursor mode)

    private func showStatusItem() {
        guard statusItem == nil else { return }
        print("[ScriptFlow] Showing status bar item for follow-cursor mode")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "■ Stop Prompter"
        item.button?.target = self
        item.button?.action = #selector(statusItemStop)
        statusItem = item
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func statusItemStop() {
        dismiss()
    }
}

// MARK: - Dynamic Island Shape (concave top corners, convex bottom corners)

struct DynamicIslandShape: Shape {
    var topInset: CGFloat = 16
    var bottomRadius: CGFloat = 18

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topInset, bottomRadius) }
        set {
            topInset = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let t = topInset
        let br = bottomRadius
        var p = Path()

        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: t, y: t),
            control: CGPoint(x: t, y: 0)
        )
        p.addLine(to: CGPoint(x: t, y: h - br))
        p.addQuadCurve(
            to: CGPoint(x: t + br, y: h),
            control: CGPoint(x: t, y: h)
        )
        p.addLine(to: CGPoint(x: w - t - br, y: h))
        p.addQuadCurve(
            to: CGPoint(x: w - t, y: h - br),
            control: CGPoint(x: w - t, y: h)
        )
        p.addLine(to: CGPoint(x: w - t, y: t))
        p.addQuadCurve(
            to: CGPoint(x: w, y: 0),
            control: CGPoint(x: w - t, y: 0)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Overlay SwiftUI View

struct NotchOverlayView: View {
    let taggedWords: [TaggedWord]
    let totalSpeakableCharCount: Int
    let speakableCharsPerPhase: [Int]
    @Bindable var speechRecognizer: SpeechRecognizer
    var branchManager: BranchManager
    let menuBarHeight: CGFloat
    let baseTextHeight: CGFloat
    let maxExtraHeight: CGFloat
    var frameTracker: NotchFrameTracker

    @State private var expansion: CGFloat = 0
    @State private var contentVisible = false
    @State private var extraHeight: CGFloat = 0
    @State private var dragStartHeight: CGFloat = -1
    @State private var isHovering: Bool = false

    // Timer-based scroll for classic & silence-paused modes
    @State private var timerWordProgress: Double = 0
    @State private var isPaused: Bool = false
    @State private var isUserScrolling: Bool = false
    private let scrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private let topInset: CGFloat = 16
    private let collapsedInset: CGFloat = 8
    private let notchHeight: CGFloat = 37
    private let notchWidth: CGFloat = 200

    private var listeningMode: ListeningMode {
        NotchSettings.shared.listeningMode
    }

    /// Convert timer word progress (display word index) → speakable char count
    private func speakableCharsForWordProgress(_ progress: Double) -> Int {
        let wholeWord = Int(progress)
        let frac = progress - Double(wholeWord)
        // Walk through display words, accumulating speakable chars
        var lastSpeakableOffset = 0
        for i in 0..<min(wholeWord, taggedWords.count) {
            let tw = taggedWords[i]
            if tw.speakableCharOffset >= 0 {
                lastSpeakableOffset = tw.speakableCharOffset + tw.word.count + 1
            }
        }
        // Handle fractional part of current word
        if wholeWord < taggedWords.count {
            let tw = taggedWords[wholeWord]
            if tw.speakableCharOffset >= 0 {
                lastSpeakableOffset = tw.speakableCharOffset + Int(Double(tw.word.count) * frac)
            }
        }
        return min(lastSpeakableOffset, totalSpeakableCharCount)
    }

    /// Convert speakable char offset → display word progress (for taps)
    private func displayWordProgressForSpeakableOffset(_ charOffset: Int) -> Double {
        for (i, tw) in taggedWords.enumerated() {
            guard tw.speakableCharOffset >= 0 else { continue }
            let end = tw.speakableCharOffset + tw.word.count
            if charOffset <= end {
                let frac = Double(charOffset - tw.speakableCharOffset) / Double(max(1, tw.word.count))
                return Double(i) + frac
            }
        }
        return Double(taggedWords.count)
    }

    private var effectiveSpeakableCharCount: Int {
        switch listeningMode {
        case .wordTracking:
            return speechRecognizer.recognizedCharCount
        case .classic, .silencePaused:
            return speakableCharsForWordProgress(timerWordProgress)
        }
    }

    var isDone: Bool {
        totalSpeakableCharCount > 0 && effectiveSpeakableCharCount >= totalSpeakableCharCount
    }

    private var currentTopInset: CGFloat {
        collapsedInset + (topInset - collapsedInset) * expansion
    }

    private var currentBottomRadius: CGFloat {
        8 + (18 - 8) * expansion
    }

    var body: some View {
        GeometryReader { geo in
            let targetHeight = menuBarHeight + baseTextHeight + extraHeight
            let currentHeight = notchHeight + (targetHeight - notchHeight) * expansion
            let currentWidth = notchWidth + (geo.size.width - notchWidth) * expansion

            ZStack(alignment: .top) {
                DynamicIslandShape(
                    topInset: currentTopInset,
                    bottomRadius: currentBottomRadius
                )
                .fill(.black)
                .frame(width: currentWidth, height: currentHeight)

                if contentVisible {
                    VStack(spacing: 0) {
                        Spacer().frame(height: menuBarHeight)

                        if isDone {
                            doneView
                        } else {
                            prompterView
                        }
                    }
                    .padding(.horizontal, topInset)
                    .frame(width: geo.size.width, height: targetHeight)
                    .transition(.opacity)
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .onChange(of: extraHeight) { _, _ in updateFrameTracker() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                expansion = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.25)) {
                    contentVisible = true
                }
            }
        }
        .onChange(of: speechRecognizer.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                withAnimation(.easeIn(duration: 0.15)) {
                    contentVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        expansion = 0
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isDone)
        .onChange(of: isDone) { _, done in
            if done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    speechRecognizer.shouldDismiss = true
                }
            }
        }
        .onReceive(scrollTimer) { _ in
            guard !isDone, !isUserScrolling else { return }
            let speed = NotchSettings.shared.scrollSpeed
            switch listeningMode {
            case .classic:
                if !isPaused {
                    timerWordProgress += speed * 0.05
                }
            case .silencePaused:
                if !isPaused && speechRecognizer.isListening && speechRecognizer.isSpeaking {
                    timerWordProgress += speed * 0.05
                }
            case .wordTracking:
                break
            }
        }
    }

    private func updateFrameTracker() {
        let targetHeight = menuBarHeight + baseTextHeight + extraHeight
        let fullWidth = NotchSettings.shared.notchWidth
        frameTracker.visibleHeight = targetHeight
        frameTracker.visibleWidth = fullWidth
    }

    private var isEffectivelyListening: Bool {
        switch listeningMode {
        case .wordTracking, .silencePaused:
            return speechRecognizer.isListening
        case .classic:
            return !isPaused
        }
    }

    private func jumpToPhase(_ phaseIndex: Int) {
        // Find first speakable word in the target phase
        guard let firstWord = taggedWords.first(where: { $0.phaseIndex == phaseIndex && $0.speakableCharOffset >= 0 }) else { return }
        if listeningMode == .wordTracking {
            speechRecognizer.jumpTo(charOffset: firstWord.speakableCharOffset)
        } else {
            timerWordProgress = displayWordProgressForSpeakableOffset(firstWord.speakableCharOffset)
        }
    }

    private var prompterView: some View {
        VStack(spacing: 0) {
            if !speakableCharsPerPhase.isEmpty {
                PhaseBarView(
                    taggedWords: taggedWords,
                    highlightedSpeakableCharCount: effectiveSpeakableCharCount,
                    speakableCharsPerPhase: speakableCharsPerPhase,
                    onPhaseSelected: { jumpToPhase($0) }
                )
                .padding(.top, 4)
            }

            SpeechScrollView(
                taggedWords: taggedWords,
                totalSpeakableCharCount: totalSpeakableCharCount,
                highlightedSpeakableCharCount: effectiveSpeakableCharCount,
                font: NotchSettings.shared.font,
                highlightColor: NotchSettings.shared.fontColorPreset.color,
                branchManager: branchManager,
                onWordTap: { speakableCharOffset in
                    guard speakableCharOffset >= 0 else { return }
                    if listeningMode == .wordTracking {
                        speechRecognizer.jumpTo(charOffset: speakableCharOffset)
                    } else {
                        timerWordProgress = displayWordProgressForSpeakableOffset(speakableCharOffset)
                    }
                },
                onManualScroll: { scrolling, newProgress in
                    isUserScrolling = scrolling
                    if !scrolling {
                        timerWordProgress = max(0, min(Double(taggedWords.count), newProgress))
                    }
                },
                smoothScroll: listeningMode != .wordTracking,
                smoothWordProgress: timerWordProgress,
                isListening: isEffectivelyListening
            )
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))

            Group {
            HStack(alignment: .center, spacing: 8) {
                AudioWaveformProgressView(
                    levels: speechRecognizer.audioLevels,
                    progress: totalSpeakableCharCount > 0
                        ? Double(effectiveSpeakableCharCount) / Double(totalSpeakableCharCount)
                        : 0
                )
                .frame(width: 160, height: 24)

                if speechRecognizer.isOffScript {
                    Text("OFF SCRIPT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                if listeningMode == .wordTracking {
                    Text(speechRecognizer.lastSpokenText.split(separator: " ").suffix(3).joined(separator: " "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(speechRecognizer.isOffScript ? 0.2 : 0.5))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }

                if listeningMode == .classic {
                    Button {
                        isPaused.toggle()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isPaused ? .white.opacity(0.6) : .yellow.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        if speechRecognizer.isListening {
                            speechRecognizer.stop()
                        } else {
                            speechRecognizer.resume()
                        }
                    } label: {
                        Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(speechRecognizer.isListening ? .yellow.opacity(0.8) : .white.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    speechRecognizer.forceStop()
                    speechRecognizer.shouldDismiss = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Resize handle - only visible on hover
            if isHovering {
                VStack(spacing: 0) {
                    Spacer().frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                    Spacer().frame(height: 8)
                }
                .frame(height: 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { value in
                            if dragStartHeight < 0 {
                                dragStartHeight = extraHeight
                            }
                            let newExtra = dragStartHeight + value.translation.height
                            extraHeight = max(0, min(maxExtraHeight, newExtra))
                        }
                        .onEnded { _ in
                            dragStartHeight = -1
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .transition(.opacity)
        }
    }

    private var doneView: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Done!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Glass Effect View

struct GlassEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

// MARK: - Floating Overlay View

struct FloatingOverlayView: View {
    let taggedWords: [TaggedWord]
    let totalSpeakableCharCount: Int
    let speakableCharsPerPhase: [Int]
    @Bindable var speechRecognizer: SpeechRecognizer
    var branchManager: BranchManager
    let baseHeight: CGFloat
    var followingCursor: Bool = false

    @State private var appeared = false

    // Timer-based scroll for classic & silence-paused modes
    @State private var timerWordProgress: Double = 0
    @State private var isPaused: Bool = false
    @State private var isUserScrolling: Bool = false
    private let scrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var listeningMode: ListeningMode {
        NotchSettings.shared.listeningMode
    }

    /// Convert timer word progress (display word index) → speakable char count
    private func speakableCharsForWordProgress(_ progress: Double) -> Int {
        let wholeWord = Int(progress)
        let frac = progress - Double(wholeWord)
        var lastSpeakableOffset = 0
        for i in 0..<min(wholeWord, taggedWords.count) {
            let tw = taggedWords[i]
            if tw.speakableCharOffset >= 0 {
                lastSpeakableOffset = tw.speakableCharOffset + tw.word.count + 1
            }
        }
        if wholeWord < taggedWords.count {
            let tw = taggedWords[wholeWord]
            if tw.speakableCharOffset >= 0 {
                lastSpeakableOffset = tw.speakableCharOffset + Int(Double(tw.word.count) * frac)
            }
        }
        return min(lastSpeakableOffset, totalSpeakableCharCount)
    }

    /// Convert speakable char offset → display word progress (for taps)
    private func displayWordProgressForSpeakableOffset(_ charOffset: Int) -> Double {
        for (i, tw) in taggedWords.enumerated() {
            guard tw.speakableCharOffset >= 0 else { continue }
            let end = tw.speakableCharOffset + tw.word.count
            if charOffset <= end {
                let frac = Double(charOffset - tw.speakableCharOffset) / Double(max(1, tw.word.count))
                return Double(i) + frac
            }
        }
        return Double(taggedWords.count)
    }

    private var effectiveSpeakableCharCount: Int {
        switch listeningMode {
        case .wordTracking:
            return speechRecognizer.recognizedCharCount
        case .classic, .silencePaused:
            return speakableCharsForWordProgress(timerWordProgress)
        }
    }

    var isDone: Bool {
        totalSpeakableCharCount > 0 && effectiveSpeakableCharCount >= totalSpeakableCharCount
    }

    private var isEffectivelyListening: Bool {
        switch listeningMode {
        case .wordTracking, .silencePaused:
            return speechRecognizer.isListening
        case .classic:
            return !isPaused
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isDone {
                floatingDoneView
            } else {
                floatingPrompterView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if NotchSettings.shared.floatingGlassEffect {
                    ZStack {
                        GlassEffectView()
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.black.opacity(NotchSettings.shared.glassOpacity))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                appeared = true
            }
        }
        .onChange(of: speechRecognizer.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                withAnimation(.easeIn(duration: 0.25)) {
                    appeared = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isDone)
        .onChange(of: isDone) { _, done in
            if done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    speechRecognizer.shouldDismiss = true
                }
            }
        }
        .onReceive(scrollTimer) { _ in
            guard !isDone, !isUserScrolling else { return }
            let speed = NotchSettings.shared.scrollSpeed
            switch listeningMode {
            case .classic:
                if !isPaused {
                    timerWordProgress += speed * 0.05
                }
            case .silencePaused:
                if !isPaused && speechRecognizer.isListening && speechRecognizer.isSpeaking {
                    timerWordProgress += speed * 0.05
                }
            case .wordTracking:
                break
            }
        }
    }

    private func jumpToPhase(_ phaseIndex: Int) {
        guard let firstWord = taggedWords.first(where: { $0.phaseIndex == phaseIndex && $0.speakableCharOffset >= 0 }) else { return }
        if listeningMode == .wordTracking {
            speechRecognizer.jumpTo(charOffset: firstWord.speakableCharOffset)
        } else {
            timerWordProgress = displayWordProgressForSpeakableOffset(firstWord.speakableCharOffset)
        }
    }

    private var floatingPrompterView: some View {
        VStack(spacing: 0) {
            if !speakableCharsPerPhase.isEmpty {
                PhaseBarView(
                    taggedWords: taggedWords,
                    highlightedSpeakableCharCount: effectiveSpeakableCharCount,
                    speakableCharsPerPhase: speakableCharsPerPhase,
                    onPhaseSelected: { jumpToPhase($0) }
                )
                .padding(.top, 8)
            }

            SpeechScrollView(
                taggedWords: taggedWords,
                totalSpeakableCharCount: totalSpeakableCharCount,
                highlightedSpeakableCharCount: effectiveSpeakableCharCount,
                font: NotchSettings.shared.font,
                highlightColor: NotchSettings.shared.fontColorPreset.color,
                branchManager: branchManager,
                onWordTap: { speakableCharOffset in
                    guard speakableCharOffset >= 0 else { return }
                    if listeningMode == .wordTracking {
                        speechRecognizer.jumpTo(charOffset: speakableCharOffset)
                    } else {
                        timerWordProgress = displayWordProgressForSpeakableOffset(speakableCharOffset)
                    }
                },
                onManualScroll: { scrolling, newProgress in
                    isUserScrolling = scrolling
                    if !scrolling {
                        timerWordProgress = max(0, min(Double(taggedWords.count), newProgress))
                    }
                },
                smoothScroll: listeningMode != .wordTracking,
                smoothWordProgress: timerWordProgress,
                isListening: isEffectivelyListening
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 8) {
                AudioWaveformProgressView(
                    levels: speechRecognizer.audioLevels,
                    progress: totalSpeakableCharCount > 0
                        ? Double(effectiveSpeakableCharCount) / Double(totalSpeakableCharCount)
                        : 0
                )
                .frame(width: 160, height: 24)

                if speechRecognizer.isOffScript {
                    Text("OFF SCRIPT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                if listeningMode == .wordTracking {
                    Text(speechRecognizer.lastSpokenText.split(separator: " ").suffix(3).joined(separator: " "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(speechRecognizer.isOffScript ? 0.2 : 0.5))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }

                if !followingCursor {
                    if listeningMode == .classic {
                        Button {
                            isPaused.toggle()
                        } label: {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isPaused ? .white.opacity(0.6) : .yellow.opacity(0.8))
                                .frame(width: 24, height: 24)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if speechRecognizer.isListening {
                                speechRecognizer.stop()
                            } else {
                                speechRecognizer.resume()
                            }
                        } label: {
                            Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(speechRecognizer.isListening ? .yellow.opacity(0.8) : .white.opacity(0.6))
                                .frame(width: 24, height: 24)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        speechRecognizer.forceStop()
                        speechRecognizer.shouldDismiss = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var floatingDoneView: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Done!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }
}
