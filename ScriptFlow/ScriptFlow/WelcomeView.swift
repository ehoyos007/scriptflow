//
//  WelcomeView.swift
//  ScriptFlow
//
//  First-run welcome sheet explaining permissions.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Welcome to ScriptFlow")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Your teleprompter for ACA enrollment calls")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    color: .blue,
                    title: "Microphone Access",
                    detail: "ScriptFlow listens to your voice to track which word you're reading."
                )
                permissionRow(
                    icon: "waveform.badge.mic",
                    color: .green,
                    title: "Speech Recognition",
                    detail: "On-device only — no audio leaves your computer."
                )
                permissionRow(
                    icon: "arrow.down.circle.fill",
                    color: .orange,
                    title: "Auto-Updates",
                    detail: "Script and app updates download automatically when available."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 420, height: 400)
    }

    private func permissionRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
