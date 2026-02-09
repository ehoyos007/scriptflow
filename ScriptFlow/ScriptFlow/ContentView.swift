//
//  ContentView.swift
//  ScriptFlow
//
//  Main window for ScriptFlow — loads script and launches teleprompter.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isRunning = false
    @State private var showSettings = false
    @State private var script: Script?
    @State private var scriptPath: String = ""
    @State private var errorMessage: String?

    private let overlayController = NotchOverlayController()

    private var languageLabel: String {
        let locale = NotchSettings.shared.speechLocale
        return Locale.current.localizedString(forIdentifier: locale) ?? locale
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ScriptFlow")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("First Health Enrollment")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: NotchSettings.shared.listeningMode.icon)
                                    .font(.system(size: 10))
                                Text(NotchSettings.shared.listeningMode == .wordTracking
                                     ? languageLabel
                                     : NotchSettings.shared.listeningMode.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider().padding(.horizontal, 16)
                }

                // Script info or loading state
                if let script = script {
                    scriptLoadedView(script)
                } else {
                    scriptPickerView
                }
            }

            // Floating action buttons (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        if script != nil {
                            // Practice mode button
                            Button {
                                run()
                            } label: {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .help("Practice Mode")
                        }

                        // Play/Stop button
                        Button {
                            if isRunning {
                                stop()
                            } else {
                                run()
                            }
                        } label: {
                            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(isRunning ? Color.red : Color.accentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(script == nil)
                        .opacity(script == nil ? 0.4 : 1)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: NotchSettings.shared)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isRunning = overlayController.isShowing
        }
        .onAppear {
            loadDefaultScript()
        }
    }

    // MARK: - Subviews

    private func scriptLoadedView(_ script: Script) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text("v\(script.version) \u{2022} \(script.phases.count) phases")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    self.script = nil
                    self.scriptPath = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Phase list
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(script.phases.enumerated()), id: \.element.id) { index, phase in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor.opacity(0.8))
                                .clipShape(Circle())
                            Text(phase.title)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(phase.blocks.count) blocks")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
    }

    private var scriptPickerView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Load a Script")
                .font(.system(size: 16, weight: .semibold))

            Text("Drop a .md script file here or click to browse")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Script File...") {
                openScriptFile()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Actions

    private func loadDefaultScript() {
        // Try loading from app bundle first
        if let bundlePath = Bundle.main.path(forResource: "aca-script", ofType: "md") {
            if let loadedScript = ScriptParser.load(from: bundlePath) {
                script = loadedScript
                scriptPath = bundlePath
                return
            }
        }
    }

    private func openScriptFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Script File"

        if panel.runModal() == .OK, let url = panel.url {
            if let loadedScript = ScriptParser.load(from: url.path) {
                script = loadedScript
                scriptPath = url.path
                errorMessage = nil
            } else {
                errorMessage = "Failed to parse script file"
            }
        }
    }

    private func run() {
        guard let script = script else { return }
        let text = script.speakableText
        guard !text.isEmpty else { return }

        overlayController.onComplete = {
            isRunning = false
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        overlayController.show(text: text)
        isRunning = true
    }

    private func stop() {
        overlayController.dismiss()
        isRunning = false
    }
}

#Preview {
    ContentView()
}
