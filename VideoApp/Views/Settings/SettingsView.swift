import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var epgURLDraft = ""
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme Colour", selection: $settings.themeAccent) {
                        Text("Green").tag("green")
                        Text("Blue").tag("blue")
                        Text("Red").tag("red")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Content Sources") {
                    Picker("VOD Source", selection: $settings.vodSource) {
                        Text("Local JSON").tag("local")
                        Text("Network API").tag("network")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EPG URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("EPG URL", text: $epgURLDraft)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Button("Reset to Default") {
                        epgURLDraft = AppSettings.defaultEpgURL
                    }
                    .font(.caption)
                }

                Section("Network") {
                    NavigationLink("Network Status") {
                        NetworkStatusView()
                    }
                }

                Section {
                    Button("Save Settings") {
                        settings.epgURL = epgURLDraft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppSettings.defaultEpgURL
                            : epgURLDraft.trimmingCharacters(in: .whitespaces)
                        showSavedToast = true
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("5G Video")
                            .font(.headline)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Part of the 5G-EMERGE project, demonstrating adaptive bitrate video streaming (HLS & DASH) over 5G networks. Content provided by Rai Play and 5G-EMERGE testbed infrastructure.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .onAppear { epgURLDraft = settings.epgURL }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Settings saved")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showSavedToast = false }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: showSavedToast)
        }
    }
}
