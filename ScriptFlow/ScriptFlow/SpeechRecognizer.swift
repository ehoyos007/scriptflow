//
//  SpeechRecognizer.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import Foundation
import Speech
import AVFoundation
import CoreAudio
import os.log

private let dbg = OSLog(subsystem: "com.fhe.ScriptFlow", category: "SpeechRecognizer")

@Observable
class SpeechRecognizer {
    var recognizedCharCount: Int = 0
    var isListening: Bool = false
    var error: String?
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    var lastSpokenText: String = ""
    var shouldDismiss: Bool = false
    var isOffScript: Bool = false

    // MARK: - Off-script detection state
    private var matchQualityWindow: [Double] = []
    private var consecutiveMissCount: Int = 0
    private var consecutiveHitCount: Int = 0
    private var frozenCharCount: Int = 0

    // Tuning constants
    private let qualityWindowSize = 5
    private let offScriptThreshold = 0.15
    private let offScriptMissesNeeded = 3
    private let reEngageHitsNeeded = 2
    private let reEngageQualityThreshold = 0.4
    private let minConsecutiveWordMatches = 2
    private let minSpokenWordsForOffScript = 3  // ignore tiny partial results

    // MARK: - Match result
    private struct MatchResult {
        let advance: Int       // char count (same semantic as old Int return)
        let quality: Double    // 0.0–1.0 match confidence
    }

    /// True when recent audio levels indicate the user is actively speaking
    var isSpeaking: Bool {
        let recent = audioLevels.suffix(10)
        guard !recent.isEmpty else { return false }
        let avg = recent.reduce(0, +) / CGFloat(recent.count)
        return avg > 0.08
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var sourceText: String = ""
    private var normalizedSource: String = ""
    private var matchStartOffset: Int = 0  // char offset to start matching from
    private var retryCount: Int = 0
    private let maxRetries: Int = 10
    private var configurationChangeObserver: Any?
    private var pendingRestart: DispatchWorkItem?

    /// Jump highlight to a specific char offset (e.g. when user taps a word)
    func jumpTo(charOffset: Int) {
        recognizedCharCount = charOffset
        matchStartOffset = charOffset
        retryCount = 0
        resetOffScriptState()
        if isListening {
            restartRecognition()
        }
    }

    func start(with text: String) {
        // Clean up any previous session immediately so pending restarts
        // and stale taps are removed before the async auth callback fires.
        cleanupRecognition()

        let collapsed = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        sourceText = collapsed
        normalizedSource = Self.normalize(collapsed)
        recognizedCharCount = 0
        matchStartOffset = 0
        retryCount = 0
        usingFallbackDevice = false
        error = nil
        resetOffScriptState()

        os_log(.error, log: dbg, "start() called, sourceText.count=%d", sourceText.count)

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                os_log(.error, log: dbg, "auth callback status=%ld", status.rawValue)
                switch status {
                case .authorized:
                    self?.beginRecognition()
                default:
                    self?.error = "Speech recognition not authorized"
                }
            }
        }
    }

    func stop() {
        isListening = false
        cleanupRecognition()
    }

    func forceStop() {
        isListening = false
        sourceText = ""
        retryCount = maxRetries
        cleanupRecognition()
    }

    func resume() {
        retryCount = 0
        matchStartOffset = recognizedCharCount
        shouldDismiss = false
        resetOffScriptState()
        beginRecognition()
    }

    private func resetOffScriptState() {
        isOffScript = false
        matchQualityWindow.removeAll()
        consecutiveMissCount = 0
        consecutiveHitCount = 0
        frozenCharCount = 0
    }

    private func cleanupRecognition() {
        // Cancel any pending restart to prevent overlapping beginRecognition calls
        pendingRestart?.cancel()
        pendingRestart = nil

        if let observer = configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationChangeObserver = nil
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Coalesces all delayed beginRecognition() calls into a single pending work item.
    /// Any previously scheduled restart is cancelled before the new one is queued.
    private func scheduleBeginRecognition(after delay: TimeInterval) {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRestart = nil
            self.beginRecognition()
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// If true, the current attempt is already a fallback to system default — don't retry device again.
    private var usingFallbackDevice = false

    private func beginRecognition() {
        os_log(.error, log: dbg, "beginRecognition() entered")
        // Ensure clean state
        cleanupRecognition()

        // Create a fresh engine so it picks up the current hardware format.
        audioEngine = AVAudioEngine()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: NotchSettings.shared.speechLocale))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            os_log(.error, log: dbg, "BAIL: speechRecognizer nil or unavailable")
            error = "Speech recognizer not available"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            os_log(.error, log: dbg, "BAIL: recognitionRequest is nil")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        // Set selected audio input device (0 = system default)
        let selectedDevice = usingFallbackDevice ? AudioDeviceID(0) : NotchSettings.shared.selectedAudioDeviceID
        os_log(.error, log: dbg, "selectedDevice=%d fallback=%d", selectedDevice, usingFallbackDevice ? 1 : 0)
        if selectedDevice != 0, let audioUnit = inputNode.audioUnit {
            var deviceID = selectedDevice
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            os_log(.error, log: dbg, "AudioUnitSetProperty status=%d", status)
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        os_log(.error, log: dbg, "recordingFormat sampleRate=%.0f channels=%d", recordingFormat.sampleRate, recordingFormat.channelCount)

        // Guard against invalid format during device transitions (e.g. mic switch)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            os_log(.error, log: dbg, "BAIL: invalid format, retryCount=%d", retryCount)
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.3)
            } else {
                error = "Audio input unavailable"
                isListening = false
            }
            return
        }

        // Observe audio configuration changes (e.g. mic switched) to restart gracefully
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.sourceText.isEmpty else { return }
            self.restartRecognition()
        }

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            let level = CGFloat(min(rms * 5, 1.0))

            DispatchQueue.main.async {
                self?.audioLevels.append(level)
                if (self?.audioLevels.count ?? 0) > 30 {
                    self?.audioLevels.removeFirst()
                }
            }
        }

        // Start engine FIRST, then create recognition task
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            // Don't reset usingFallbackDevice here — wait until we get a real recognition result
            os_log(.error, log: dbg, "engine started OK. device=%d sampleRate=%.0f sourceLen=%d", selectedDevice, recordingFormat.sampleRate, sourceText.count)
        } catch {
            os_log(.error, log: dbg, "engine start THREW: %{public}@", error.localizedDescription)
            // If a custom device failed, fall back to system default before burning retries
            if !usingFallbackDevice && selectedDevice != 0 {
                os_log(.error, log: dbg, "falling back to system default device")
                usingFallbackDevice = true
                cleanupRecognition()
                scheduleBeginRecognition(after: 0.1)
            } else if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.3)
            } else {
                self.error = "Audio engine failed: \(error.localizedDescription)"
                isListening = false
            }
            return
        }

        // Only create recognition task after engine is running
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, taskError in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                os_log(.error, log: dbg, "recognition result: %{public}@", String(spoken.prefix(80)))
                DispatchQueue.main.async {
                    self.retryCount = 0
                    self.usingFallbackDevice = false  // got real speech — device is working
                    self.lastSpokenText = spoken
                    self.matchCharacters(spoken: spoken)
                }
            }
            if let taskError {
                os_log(.error, log: dbg, "recognitionTask error: %{public}@", taskError.localizedDescription)
                DispatchQueue.main.async {
                    guard self.recognitionRequest != nil else { return }
                    // Advance matchStartOffset so the next session matches from where we left off
                    self.matchStartOffset = self.recognizedCharCount
                    if self.isListening && !self.shouldDismiss && !self.sourceText.isEmpty && self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        let delay = min(Double(self.retryCount) * 0.5, 1.5)
                        self.scheduleBeginRecognition(after: delay)
                    } else {
                        self.isListening = false
                    }
                }
            }
        }
    }

    private func restartRecognition() {
        // Reset retries so the fresh engine gets a full set of attempts
        retryCount = 0
        isListening = true
        // Longer delay to let the audio system fully settle after a device change
        cleanupRecognition()
        scheduleBeginRecognition(after: 0.5)
    }

    // MARK: - Fuzzy character-level matching

    private func matchCharacters(spoken: String) {
        // Strategy 1: character-level fuzzy match from the start offset
        let charResult = charLevelMatch(spoken: spoken)

        // Strategy 2: word-level match (handles STT word substitutions)
        let wordResult = wordLevelMatch(spoken: spoken)

        // Pick the strategy with the best advance
        let best = charResult.advance >= wordResult.advance ? charResult : wordResult
        let quality = best.quality

        let spokenPreview = String(spoken.prefix(80))
        let sourcePreview = String(sourceText.dropFirst(matchStartOffset).prefix(50))
        os_log(.error, log: dbg, "Match spoken=%{public}@ charAdv=%d charQ=%.2f wordAdv=%d wordQ=%.2f offset=%d recognized=%d offScript=%d source=%{public}@", spokenPreview, charResult.advance, charResult.quality, wordResult.advance, wordResult.quality, matchStartOffset, recognizedCharCount, isOffScript ? 1 : 0, sourcePreview)

        // Update rolling quality window
        matchQualityWindow.append(quality)
        if matchQualityWindow.count > qualityWindowSize {
            matchQualityWindow.removeFirst()
        }

        // Skip off-script logic for tiny partial results (e.g. "hello" before "hello my name")
        let spokenWordCount = spoken.split(separator: " ").count
        let hasEnoughContext = spokenWordCount >= minSpokenWordsForOffScript

        // Off-script detection
        if isOffScript {
            // Currently off-script — check for re-engagement
            if quality >= reEngageQualityThreshold {
                consecutiveHitCount += 1
            } else {
                consecutiveHitCount = 0
            }
            if consecutiveHitCount >= reEngageHitsNeeded {
                // Re-engage: resume tracking from frozen position
                isOffScript = false
                consecutiveMissCount = 0
                consecutiveHitCount = 0
                matchStartOffset = frozenCharCount
            }
            // While off-script, do NOT update recognizedCharCount
            return
        }

        // On-script — check for off-script trigger (only with enough spoken context)
        if hasEnoughContext {
            if quality < offScriptThreshold {
                consecutiveMissCount += 1
                consecutiveHitCount = 0
            } else {
                consecutiveMissCount = 0
                consecutiveHitCount += 1
            }

            if consecutiveMissCount >= offScriptMissesNeeded {
                // Freeze position
                isOffScript = true
                frozenCharCount = recognizedCharCount
                consecutiveHitCount = 0
                return
            }
        }

        // Normal progression — only move forward
        let newCount = matchStartOffset + best.advance
        if newCount > recognizedCharCount {
            recognizedCharCount = min(newCount, sourceText.count)
        }
    }

    private func charLevelMatch(spoken: String) -> MatchResult {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let src = Array(remainingSource.lowercased().unicodeScalars).map { Character($0) }
        let spk = Array(Self.normalize(spoken).unicodeScalars).map { Character($0) }

        var si = 0
        var ri = 0
        var lastGoodOrigIndex = 0
        var matchedChars = 0

        while si < src.count && ri < spk.count {
            let sc = src[si]
            let rc = spk[ri]

            // Skip non-alphanumeric in source
            if !sc.isLetter && !sc.isNumber {
                si += 1
                continue
            }
            // Skip non-alphanumeric in spoken
            if !rc.isLetter && !rc.isNumber {
                ri += 1
                continue
            }

            if sc == rc {
                si += 1
                ri += 1
                matchedChars += 1
                lastGoodOrigIndex = si
            } else {
                // Try to re-sync: look ahead in both strings
                var found = false

                // Skip up to 2 chars in spoken (reduced from 3)
                let maxSkipR = min(2, spk.count - ri - 1)
                if maxSkipR >= 1 {
                    for skipR in 1...maxSkipR {
                        let nextRI = ri + skipR
                        if nextRI < spk.count && spk[nextRI] == sc {
                            ri = nextRI
                            found = true
                            break
                        }
                    }
                }
                if found { continue }

                // Skip up to 2 chars in source (reduced from 3)
                let maxSkipS = min(2, src.count - si - 1)
                if maxSkipS >= 1 {
                    for skipS in 1...maxSkipS {
                        let nextSI = si + skipS
                        if nextSI < src.count && src[nextSI] == rc {
                            si = nextSI
                            found = true
                            break
                        }
                    }
                }
                if found { continue }

                // Skip both (substitution) — don't count as matched for quality
                si += 1
                ri += 1
            }
        }

        let spokenAlphanumCount = spk.filter { $0.isLetter || $0.isNumber }.count
        let quality = spokenAlphanumCount > 0
            ? Double(matchedChars) / Double(spokenAlphanumCount)
            : 0.0
        return MatchResult(advance: lastGoodOrigIndex, quality: quality)
    }

    private static func isAnnotationWord(_ word: String) -> Bool {
        if word.hasPrefix("[") && word.hasSuffix("]") { return true }
        let stripped = word.filter { $0.isLetter || $0.isNumber }
        return stripped.isEmpty
    }

    private func wordLevelMatch(spoken: String) -> MatchResult {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let sourceWords = remainingSource.split(separator: " ").map { String($0) }
        let spokenWords = spoken.lowercased().split(separator: " ").map { String($0) }

        var si = 0 // source word index
        var ri = 0 // spoken word index

        // Quality tracking (all matches, for off-script detection)
        var totalMatchedSourceWords = 0
        var totalSpokenWordsProcessed = 0

        // Consecutive-match confirmation buffer:
        // Only commit advancement after minConsecutiveWordMatches consecutive hits.
        var pendingCharCount = 0
        var consecutiveMatches = 0
        var committedCharCount = 0

        while si < sourceWords.count && ri < spokenWords.count {
            // Auto-skip annotation words in source (brackets, emoji)
            if Self.isAnnotationWord(sourceWords[si]) {
                pendingCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { pendingCharCount += 1 }
                si += 1
                continue
            }

            let srcWord = sourceWords[si].lowercased()
                .filter { $0.isLetter || $0.isNumber }
            let spkWord = spokenWords[ri]
                .filter { $0.isLetter || $0.isNumber }

            var matched = false

            if srcWord == spkWord || isFuzzyMatch(srcWord, spkWord) {
                pendingCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { pendingCharCount += 1 }
                totalMatchedSourceWords += 1
                totalSpokenWordsProcessed += 1
                consecutiveMatches += 1
                si += 1
                ri += 1
                matched = true
            } else {
                // Try skipping up to 2 spoken words (STT hallucinated words)
                var foundSpk = false
                let maxSpkSkip = min(2, spokenWords.count - ri - 1)
                if maxSpkSkip >= 1 {
                    for skip in 1...maxSpkSkip {
                        let nextSpk = spokenWords[ri + skip].filter { $0.isLetter || $0.isNumber }
                        if srcWord == nextSpk || isFuzzyMatch(srcWord, nextSpk) {
                            totalSpokenWordsProcessed += skip
                            ri += skip
                            foundSpk = true
                            break
                        }
                    }
                }
                if foundSpk { continue }

                // Try skipping up to 2 source words (user read fast, STT missed words)
                var foundSrc = false
                let maxSrcSkip = min(2, sourceWords.count - si - 1)
                if maxSrcSkip >= 1 {
                    for skip in 1...maxSrcSkip {
                        let nextSrc = sourceWords[si + skip].lowercased().filter { $0.isLetter || $0.isNumber }
                        if nextSrc == spkWord || isFuzzyMatch(nextSrc, spkWord) {
                            for s in 0..<skip {
                                pendingCharCount += sourceWords[si + s].count + 1
                            }
                            si += skip
                            foundSrc = true
                            break
                        }
                    }
                }
                if foundSrc { continue }

                // Try treating current source word as punctuation-only and skip it
                if srcWord.isEmpty {
                    pendingCharCount += sourceWords[si].count
                    if si < sourceWords.count - 1 { pendingCharCount += 1 }
                    si += 1
                    continue
                }
                // No match — advance spoken, reset consecutive count
                totalSpokenWordsProcessed += 1
                ri += 1
                consecutiveMatches = 0
                pendingCharCount = 0  // discard uncommitted on miss
            }

            // Commit pending buffer once we have enough consecutive matches
            if matched && consecutiveMatches >= minConsecutiveWordMatches {
                committedCharCount += pendingCharCount
                pendingCharCount = 0
            }
        }

        // Auto-skip trailing annotation words at end of committed source
        if committedCharCount > 0 {
            while si < sourceWords.count && Self.isAnnotationWord(sourceWords[si]) {
                committedCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { committedCharCount += 1 }
                si += 1
            }
        }

        // Quality uses ALL matches seen (not just committed) for off-script detection
        let quality = totalSpokenWordsProcessed > 0
            ? Double(totalMatchedSourceWords) / Double(totalSpokenWordsProcessed)
            : 0.0
        return MatchResult(advance: committedCharCount, quality: quality)
    }

    private func isFuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a.isEmpty || b.isEmpty { return false }
        // Exact match
        if a == b { return true }
        // Prefix match — only if shorter word is >= 4 chars
        let shorter = min(a.count, b.count)
        if shorter >= 4 && (a.hasPrefix(b) || b.hasPrefix(a)) { return true }
        // Shared prefix >= 75% of shorter word, minimum 3 shared chars
        let shared = zip(a, b).prefix(while: { $0 == $1 }).count
        if shared >= 3 && shorter >= 3 && shared >= (shorter * 3 + 3) / 4 { return true }
        // Edit distance tolerance (tighter thresholds)
        let dist = editDistance(a, b)
        if shorter <= 4 { return dist == 0 }   // exact only for short words
        if shorter <= 8 { return dist <= 1 }
        return dist <= max(a.count, b.count) / 4
    }

    private func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, dp[j], dp[j-1]) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }
}
