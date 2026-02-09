//
//  SettingsView.swift
//  ScriptFlow
//
//  Simplified settings for ScriptFlow teleprompter.
//

import SwiftUI
import Speech

struct SettingsView: View {
    @Bindable var settings: NotchSettings
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Display").tag(0)
                Text("Speech").tag(1)
                Text("Text").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Divider().padding(.top, 12)

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0: displaySettings
                    case 1: speechSettings
                    case 2: textSettings
                    default: EmptyView()
                    }
                }
                .padding(20)
            }

            Divider()

            // Done button
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(16)
        }
        .frame(width: 380, height: 420)
        .background(.ultraThinMaterial)
    }

    // MARK: - Display Settings

    private var displaySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSection("Overlay Size") {
                VStack(spacing: 8) {
                    HStack {
                        Text("Width")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(settings.notchWidth))pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.notchWidth,
                           in: NotchSettings.minWidth...NotchSettings.maxWidth,
                           step: 10)

                    HStack {
                        Text("Height")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(settings.textAreaHeight))pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.textAreaHeight,
                           in: NotchSettings.minHeight...NotchSettings.maxHeight,
                           step: 10)
                }
            }

            settingsSection("Appearance") {
                Toggle("Glass effect", isOn: $settings.floatingGlassEffect)
                    .font(.system(size: 13))
                if settings.floatingGlassEffect {
                    HStack {
                        Text("Opacity")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.glassOpacity, in: 0.05...0.5)
                    }
                }
            }
        }
    }

    // MARK: - Speech Settings

    private var speechSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            listeningModeSection
            scrollSpeedSection
            settingsSection("Language") {
                languagePicker
            }
        }
    }

    private var listeningModeSection: some View {
        settingsSection("Listening Mode") {
            listeningModeList
        }
    }

    private var listeningModeList: some View {
        VStack(spacing: 4) {
            ForEach(ListeningMode.allCases) { mode in
                listeningModeRow(mode: mode)
            }
        }
    }

    private func listeningModeRow(mode: ListeningMode) -> some View {
        let isSelected = settings.listeningMode == mode
        return Button {
            settings.listeningMode = mode
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.system(size: 13, weight: .medium))
                    Text(mode.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var scrollSpeedSection: some View {
        if settings.listeningMode == .classic || settings.listeningMode == .silencePaused {
            settingsSection("Scroll Speed") {
                HStack {
                    Text("Slow").font(.system(size: 11)).foregroundStyle(.secondary)
                    Slider(value: $settings.scrollSpeed, in: 0.5...8.0, step: 0.5)
                    Text("Fast").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text("\(String(format: "%.1f", settings.scrollSpeed)) words/sec")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Text Settings

    private var textSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSection("Font Family") {
                HStack(spacing: 8) {
                    ForEach(FontFamilyPreset.allCases) { preset in
                        Button {
                            settings.fontFamilyPreset = preset
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.sampleText)
                                    .font(Font(preset.font(size: 18)))
                                    .frame(width: 44, height: 36)
                                Text(preset.label)
                                    .font(.system(size: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(settings.fontFamilyPreset == preset ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(settings.fontFamilyPreset == preset ? Color.accentColor : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection("Font Size") {
                HStack(spacing: 8) {
                    ForEach(FontSizePreset.allCases) { preset in
                        Button {
                            settings.fontSizePreset = preset
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(settings.fontSizePreset == preset ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(settings.fontSizePreset == preset ? Color.accentColor : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection("Highlight Color") {
                HStack(spacing: 8) {
                    ForEach(FontColorPreset.allCases) { preset in
                        Button {
                            settings.fontColorPreset = preset
                        } label: {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(settings.fontColorPreset == preset ? .white : .clear, lineWidth: 2)
                                )
                                .shadow(color: preset.color.opacity(0.4), radius: settings.fontColorPreset == preset ? 4 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private var languagePicker: some View {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
            .sorted { ($0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) < ($1.localizedString(forIdentifier: $1.identifier) ?? $1.identifier) }

        return Picker("Language", selection: $settings.speechLocale) {
            ForEach(supportedLocales.map(\.identifier), id: \.self) { localeID in
                Text(Locale.current.localizedString(forIdentifier: localeID) ?? localeID)
                    .tag(localeID)
            }
        }
        .font(.system(size: 13))
    }
}
