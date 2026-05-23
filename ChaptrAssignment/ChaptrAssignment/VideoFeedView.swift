import SwiftUI
import AVKit
import CoreMedia
import UIKit

// MARK: - Feed
struct VideoFeedView: View {
    @State private var videos: [VideoItem] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var error: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading videos...")
            } else if let error = error {
                VStack(spacing: 16) {
                    Text("Error: \(error)")
                    Button("Retry") { loadVideos() }
                }
            } else {
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                                VideoPlayerView(
                                    video: video,
                                    isActive: currentIndex == index
                                )
                                .frame(width: geo.size.width, height: geo.size.height)
                                .background(
                                    GeometryReader { cellGeo -> Color in
                                        let minY = cellGeo.frame(in: .global).minY
                                        let height = geo.size.height
                                        DispatchQueue.main.async {
                                            if abs(minY) < height / 2 {
                                                currentIndex = index
                                            }
                                        }
                                        return Color.clear
                                    }
                                )
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()
            }
        }
        .onAppear(perform: loadVideos)
        // Prefetch thumbnails for the next 3 videos whenever the active index changes
        .onChange(of: currentIndex) { index in
            prefetchUpcoming(from: index)
        }
    }

    private func loadVideos() {
        isLoading = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = VideoDataLoader.loadCatalog()
            DispatchQueue.main.async {
                if loaded.isEmpty {
                    self.error = "No videos found or failed to load."
                } else {
                    self.videos = loaded
                    self.prefetchUpcoming(from: 0)
                }
                self.isLoading = false
            }
        }
    }
    
    private func prefetchUpcoming(from index: Int, lookahead: Int = 5) {
        let end = min(index + lookahead, videos.count)
        guard index < end else { return }
        let urls = videos[index..<end].map(\.thumbnail)
        VideoCache.shared.prefetchThumbnails(for: urls)
    }
}

// MARK: - Player

struct VideoPlayerView: View {
    let video: VideoItem
    let isActive: Bool

    @State private var player: AVPlayer? = nil
    @State private var isLiked: Bool = false
    @State private var progress: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var isPlaying: Bool = true
    @State private var showPlayPause: Bool = false
    @State private var playPauseTask: DispatchWorkItem? = nil
    @State private var progressTimer: Timer? = nil
    @State private var isBuffering: Bool = true
    @State private var playerStatusObserver: Any? = nil

    private var likeCount: String  { formatCount(video.id % 500_000 + 10_000) }
    private var shareCount: String { formatCount(video.id % 50_000  + 1_000)  }
    private var sendCount: String  { formatCount(video.id % 80_000  + 5_000)  }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .opacity(isBuffering ? 0 : 1)
                    .onChange(of: isActive) { active in
                        if active {
                            player.seek(to: .zero)
                            player.play()
                            isPlaying = true
                            startProgressTimer()
                        } else {
                            player.pause()
                            isPlaying = false
                            stopProgressTimer()
                        }
                    }
            }

           
            if isBuffering {
                GeometryReader { geo in
                    CachedAsyncImage(urlString: video.thumbnail, contentMode: .fit)
                        .background(Color.black)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }

            if isBuffering {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlayback()
                }

            if showPlayPause {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 80, height: 80)

                    Image(systemName: isPlaying ? "play.fill" : "pause.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(spacing: 20) {
                Spacer()

                ActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    label: likeCount,
                    tint: isLiked ? .red : .white
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isLiked.toggle()
                    }
                }

                ActionButton(icon: "arrow.2.squarepath", label: shareCount) {}
                ActionButton(icon: "paperplane", label: sendCount) {}

                ThumbnailButton(url: video.thumbnail)

                Spacer().frame(height: 80)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(video.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.trailing, 80)
            .padding(.bottom, 78)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer()
                    ProgressBarView(
                        progress: progress,
                        isScrubbing: $isScrubbing,
                        onDrag: { fraction in seekDragging(to: fraction) },
                        onCommit: { fraction in seekFinal(to: fraction) }
                    )
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 49)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()

        .onAppear {
            guard player == nil else { return }
            guard let item = VideoCache.shared.playerItem(for: video.url) else { return }
            let p = AVPlayer(playerItem: item)

            playerStatusObserver = p.currentItem?.observe(
                \.status,
                options: [.new]
            ) { [weak p] observedItem, _ in
                guard observedItem.status == .readyToPlay else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isBuffering = false   // swap thumbnail → live video
                    }
                }
            }

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                p.seek(to: .zero)
                progress = 0
                if isActive { p.play() }
            }

            player = p
            if isActive {
                p.play()
                isPlaying = true
                startProgressTimer()
            }
        }
        .onDisappear {
            playerStatusObserver = nil
            player?.pause()
            player = nil
            isPlaying = false
            isBuffering = true 
            stopProgressTimer()
            progress = 0
        }
    }

    // MARK: - Play / Pause

    private func togglePlayback() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            stopProgressTimer()
        } else {
            p.play()
            startProgressTimer()
        }
        isPlaying.toggle()

        playPauseTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { showPlayPause = true }
        let task = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.25)) { showPlayPause = false }
        }
        playPauseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
    }

    // MARK: - Seek

    private func seekDragging(to fraction: Double) {
        guard
            let p = player,
            let item = p.currentItem,
            item.duration.seconds.isFinite,
            item.duration.seconds > 0
        else { return }

        let loose = CMTime(seconds: 0.5, preferredTimescale: 600)
        let time  = CMTime(seconds: fraction * item.duration.seconds, preferredTimescale: 600)
        p.seek(to: time, toleranceBefore: loose, toleranceAfter: loose)
        if isPlaying && p.timeControlStatus != .playing { p.play() }
        progress = fraction
    }

    private func seekFinal(to fraction: Double) {
        guard
            let p = player,
            let item = p.currentItem,
            item.duration.seconds.isFinite,
            item.duration.seconds > 0
        else { return }

        let tight = CMTime(seconds: 0.1, preferredTimescale: 600)
        let time  = CMTime(seconds: fraction * item.duration.seconds, preferredTimescale: 600)
        p.seek(to: time, toleranceBefore: tight, toleranceAfter: tight) { _ in
            if self.isActive && self.isPlaying { p.play() }
        }
        progress = fraction
    }

    // MARK: - Timer

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            guard
                !isScrubbing,
                let p = player,
                let item = p.currentItem,
                item.duration.seconds.isFinite,
                item.duration.seconds > 0
            else { return }
            progress = p.currentTime().seconds / item.duration.seconds
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Helpers

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(tint)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thumbnail Button

struct ThumbnailButton: View {
    let url: String

    var body: some View {
        Button(action: {}) {
            CachedAsyncImage(urlString: url)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let progress: Double
    @Binding var isScrubbing: Bool
    let onDrag: (Double) -> Void
    let onCommit: (Double) -> Void

    @State private var dragProgress: Double? = nil

    private var displayProgress: Double {
        dragProgress ?? progress
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let trackHeight: CGFloat = isScrubbing ? 4 : 3
            let thumbSize: CGFloat = 14

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, w * CGFloat(displayProgress)), height: trackHeight)

                if isScrubbing {
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, w * CGFloat(displayProgress) - thumbSize / 2))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            withAnimation(.easeOut(duration: 0.12)) {
                                isScrubbing = true
                            }
                        }
                        let fraction = (value.location.x / w).clamped(to: 0...1)
                        dragProgress = fraction
                        onDrag(fraction)
                    }
                    .onEnded { value in
                        let fraction = (value.location.x / w).clamped(to: 0...1)
                        dragProgress = nil
                        withAnimation(.easeIn(duration: 0.12)) {
                            isScrubbing = false
                        }
                        onCommit(fraction)
                    }
            )
        }
        .frame(height: 28)
        .animation(.easeInOut(duration: 0.12), value: isScrubbing)
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
