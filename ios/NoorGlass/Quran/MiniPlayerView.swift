//
//  MiniPlayerView.swift
//  Noor Glass
//
//  Quran player (v2.1.0-private): the persistent mini player — a
//  deep-green bar with the surah's Arabic tile, names, a hairline
//  progress track and transport controls. Tapping the bar (outside
//  the buttons) opens Now Playing via `onOpen`. Used at the bottom
//  of the Quran library and as the app-wide overlay above the home
//  layouts. Target Membership: NoorGlass only.
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: QuranPlayer
    let onOpen: () -> Void
    @State private var dragX: CGFloat = 0

    var body: some View {
        if let surah = player.currentSurah {
            VStack(spacing: 0) {
                // Build 3 layout: the pill now gets its own
                // full-width row (safe-area inset in ContentView,
                // not the squeezed tab-bar accessory), so the tile,
                // titles and transport controls each get real room:
                // 40 pt tile, titles truncate cleanly at the tail
                // (no shrink-to-fit), fixed-size controls.
                HStack(spacing: 10) {
                    Button(action: onOpen) {
                        HStack(spacing: 10) {
                            Text(surah.arabic)
                                .font(.headline)
                                .foregroundStyle(QuranTheme.deepGreen)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 2)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(colors: [QuranTheme.lightGold, QuranTheme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(surah.english)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if let playbackError = player.playbackError {
                                    // Build 3 failure surface: a
                                    // failed stream says so here
                                    // instead of posing as playing.
                                    // Play retries the load.
                                    Label(playbackError, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.yellow)
                                        .lineLimit(1)
                                } else {
                                    Text(player.currentReciter?.name ?? "")
                                        .font(.caption)
                                        .foregroundStyle(QuranTheme.mutedOnGreen)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)

                    transportButton("backward.end.fill") { player.previous() }
                    if player.isBuffering && player.playbackError == nil {
                        // Told to play but AVFoundation is still
                        // waiting for data: a spinner here instead
                        // of a pause glyph over silence.
                        ProgressView()
                            .tint(.white)
                            .frame(width: 36, height: 36)
                    } else {
                        transportButton(player.isPlaying ? "pause.fill" : "play.fill") {
                            player.togglePlayPause()
                        }
                    }
                    transportButton("forward.end.fill") { player.next() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(QuranTheme.lightGold)
                            .frame(width: proxy.size.width * progressFraction)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 12)
                .padding(.bottom, 7)
            }
            // Noor Glass: Liquid Glass pill (iOS 26) tinted with the
            // Quran deep green, replacing the flat fill + shadow.
            .glassEffect(.regular.tint(QuranTheme.deepGreen.opacity(0.88))
                            .interactive(),
                         in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            // The full player's gestures, on the pill (build 31):
            // swipe left/right to skip surahs (the pill follows the
            // finger and springs back), swipe up to expand back
            // into Now Playing. High priority so the paged TabView
            // underneath does not also turn its page.
            .offset(x: dragX)
            .highPriorityGesture(pillGesture)
        }
    }

    private var pillGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                if abs(value.translation.width)
                    > abs(value.translation.height) * 1.5 {
                    dragX = value.translation.width * 0.3
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    dragX = 0
                }
                if abs(dx) > abs(dy) * 1.5 {
                    if dx < -60 { player.next() }
                    else if dx > 60 { player.previous() }
                } else if dy < -45 {
                    onOpen()
                }
            }
    }

    private var progressFraction: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, player.currentTime / player.duration)))
    }

    private func transportButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}
