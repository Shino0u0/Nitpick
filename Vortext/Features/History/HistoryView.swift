import AVFoundation
import AppKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \HistoryEntry.createdAt, order: .reverse)
    private var entries: [HistoryEntry]
    @State private var selection: HistoryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NPEyebrow("History")
                Spacer()
                if !entries.isEmpty {
                    Button("Clear History") {
                        try? appState.store.clearHistory()
                        selection = nil
                    }
                    .buttonStyle(NPCapsuleButtonStyle())
                }
            }
            if entries.isEmpty {
                emptyState
            } else {
                HSplitView {
                    list
                        .frame(minWidth: 250, idealWidth: 280)
                    detail
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(NP.inkSecondary)
            Text("Nothing here yet")
                .font(.headline)
            Text("Press ⌥⌘D anywhere to dictate. Your transcripts land here.")
                .font(.callout)
                .foregroundStyle(NP.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(entries, id: \.id, selection: Binding(
            get: { selection?.id },
            set: { id in selection = entries.first { $0.id == id } }
        )) { entry in
            HistoryRow(entry: entry)
                .tag(entry.id)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(NP.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NP.border))
    }

    @ViewBuilder
    private var detail: some View {
        if let entry = selection {
            HistoryDetailView(entry: entry) {
                try? appState.store.deleteHistory(entry)
                selection = nil
            }
            .id(entry.id)
            .padding(.leading, 12)
        } else {
            Text("Select an entry")
                .foregroundStyle(NP.inkSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: entry.action == .dictate ? "mic" : "questionmark.bubble")
                    .font(.caption)
                    .foregroundStyle(NP.inkSecondary)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(NP.inkSecondary)
                if let duration = entry.duration {
                    Text("\(Int(duration))s")
                        .font(.caption2)
                        .foregroundStyle(NP.inkSecondary)
                }
                Spacer()
                statusBadge
            }
            Text(entry.finalOutput ?? entry.originalTranscript)
                .font(.callout)
                .lineLimit(2)
            HStack(spacing: 6) {
                if let modeName = entry.modeName {
                    Text(modeName).font(.caption2).foregroundStyle(NP.inkSecondary)
                }
                if let app = entry.targetAppName {
                    Text("→ \(app)").font(.caption2).foregroundStyle(NP.inkSecondary)
                }
                ForEach(entry.usedContext, id: \.self) { source in
                    Text(source.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(NP.canvasSecondary, in: Capsule())
                }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch entry.status {
        case .succeeded:
            EmptyView()
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
                .labelStyle(.titleAndIcon)
        case .cancelled:
            Text("Cancelled").font(.caption2).foregroundStyle(NP.inkSecondary)
        }
    }
}

private struct HistoryDetailView: View {
    @Environment(AppState.self) private var appState
    let entry: HistoryEntry
    let onDelete: () -> Void
    @State private var original: String = ""
    @State private var final: String = ""
    @State private var player = AudioPlayerModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                editor("Original", text: $original) {
                    entry.originalTranscript = original
                    try? appState.store.save()
                }
                editor("Final", text: $final) {
                    entry.finalOutput = final
                    try? appState.store.save()
                }
                if entry.status == .failed, let category = entry.errorCategory {
                    Label(
                        AppState.message(for: category),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.callout)
                    .foregroundStyle(.red)
                }
                if let url = entry.audioFileURL,
                    FileManager.default.fileExists(atPath: url.path) {
                    AudioPlayerView(model: player, url: url)
                }
                HStack {
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(NPCapsuleButtonStyle())
                    Spacer()
                }
            }
            .padding(2)
        }
        .onAppear {
            original = entry.originalTranscript
            final = entry.finalOutput ?? ""
        }
    }

    private func editor(
        _ title: String, text: Binding<String>, save: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                NPEyebrow(title)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text.wrappedValue, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(NP.inkSecondary)
                .accessibilityLabel("Copy \(title.lowercased()) text")
            }
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: 64)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(NP.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(NP.border))
                .onChange(of: text.wrappedValue) { save() }
        }
    }
}

// MARK: - Audio playback

@MainActor
@Observable
final class AudioPlayerModel: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var ticker: Timer?

    func load(url: URL) {
        guard player?.url != url else { return }
        stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        duration = player?.duration ?? 0
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            ticker?.invalidate()
        } else {
            player.play()
            isPlaying = true
            ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) {
                [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    elapsed = self.player?.currentTime ?? 0
                }
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        elapsed = time
    }

    func stop() {
        player?.stop()
        ticker?.invalidate()
        isPlaying = false
        elapsed = 0
    }

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer, successfully flag: Bool
    ) {
        Task { @MainActor in
            isPlaying = false
            elapsed = 0
            ticker?.invalidate()
        }
    }
}

struct AudioPlayerView: View {
    @Bindable var model: AudioPlayerModel
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.toggle()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 24)
                    .background(NP.canvasSecondary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isPlaying ? "Pause audio" : "Play audio")
            Slider(
                value: Binding(
                    get: { model.elapsed },
                    set: { model.seek(to: $0) }
                ),
                in: 0...max(model.duration, 0.1)
            )
            Text(timeLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(NP.inkSecondary)
        }
        .npCard()
        .onAppear { model.load(url: url) }
        .onDisappear { model.stop() }
    }

    private var timeLabel: String {
        func format(_ value: TimeInterval) -> String {
            let seconds = Int(value.rounded())
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return "\(format(model.elapsed)) / \(format(model.duration))"
    }
}
