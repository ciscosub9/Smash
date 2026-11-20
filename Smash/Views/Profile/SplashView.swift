import SwiftUI

// MARK: - SplashView
//
// Big-shuttle splash: a shuttlecock zooms in from tiny to cover the whole
// screen, then "Smash" + "Play it smart" appear. RootView presents this on a
// fresh launch; tap anywhere to finish early.
//
// Keyframe offsets mirror the 1.6s timeline in shuttlecock-animation.html.
//
// Asset required: add the Boxicons "shuttlecock" SVG to your asset catalog as
// `Shuttlecock.imageset/Shuttlecock.svg` (template rendering). The SVG is the
// same one shipped in the preview (shuttlecock-animation.html).

struct SplashView: View {
    static let duration: TimeInterval = 1.6
    static let shuttleSize: CGFloat = 56

    var onFinish: (() -> Void)? = nil

    @State private var play = false
    @State private var didFinish = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let layout = SplashLayout(size: proxy.size)
            if reduceMotion {
                SplashScene(layout: layout, pose: layout.finalPose)
            } else {
                SplashScene(layout: layout, pose: layout.startPose)
                    .keyframeAnimator(initialValue: layout.startPose, trigger: play) { _, pose in
                        SplashScene(layout: layout, pose: pose)
                    } keyframes: { _ in
                        let cover = Double(layout.coverScale)
                        let duration = SplashView.duration

                        // Reference offsets: scale 12 (covered) at 0.625 =
                        // 1.0s, 14 at 0.75 = 1.2s, then hold to 1.6s.
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(cover, duration: duration * 0.625)
                            CubicKeyframe(cover * 14.0 / 12.0, duration: duration * 0.125)
                            CubicKeyframe(cover * 14.0 / 12.0, duration: duration * 0.25)
                        }
                        KeyframeTrack(\.opacity) {
                            CubicKeyframe(0.18, duration: duration * 0.625)
                            CubicKeyframe(0.14, duration: duration * 0.125)
                            CubicKeyframe(0.12, duration: duration * 0.25)
                        }
                        KeyframeTrack(\.rotation) {
                            CubicKeyframe(0, duration: duration * 0.625)
                            CubicKeyframe(0, duration: duration * 0.375)
                        }

                        // Text appears at offset 0.78 = 1.25s and settles by 1.44s.
                        KeyframeTrack(\.textOpacity) {
                            LinearKeyframe(0, duration: duration * 0.625)
                            CubicKeyframe(1, duration: duration * 0.155)
                            LinearKeyframe(1, duration: duration * 0.12)
                            LinearKeyframe(1, duration: duration * 0.10)
                        }
                        KeyframeTrack(\.textScale) {
                            LinearKeyframe(0.85, duration: duration * 0.625)
                            CubicKeyframe(1.05, duration: duration * 0.155)
                            CubicKeyframe(1.00, duration: duration * 0.12)
                            LinearKeyframe(1.00, duration: duration * 0.10)
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .background(.black)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear {
            if reduceMotion {
                scheduleFinish(delay: 0.5)
            } else {
                play = true
                scheduleFinish(delay: Self.duration)
            }
        }
    }

    private func scheduleFinish(delay: TimeInterval) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinish?()
    }
}

// MARK: - Pose

private struct SplashPose: Equatable {
    var scale: Double
    var opacity: Double
    var rotation: Double
    var textOpacity: Double
    var textScale: Double
}

// MARK: - Layout

private struct SplashLayout {
    let size: CGSize
    let coverScale: CGFloat

    init(size: CGSize) {
        self.size = size
        // Scale needed for the 56pt glyph to cover the whole screen.
        coverScale = hypot(size.width, size.height) / SplashView.shuttleSize * 1.15
    }

    var startPose: SplashPose {
        SplashPose(scale: 0.05, opacity: 0.3, rotation: -20,
                   textOpacity: 0, textScale: 0.85)
    }

    var finalPose: SplashPose {
        // Matches the last keyframe (reference scale 14 relative to 12).
        SplashPose(scale: Double(coverScale) * 14.0 / 12.0, opacity: 0.12, rotation: 0,
                   textOpacity: 1, textScale: 1)
    }
}

// MARK: - Scene

private struct SplashScene: View {
    let layout: SplashLayout
    let pose: SplashPose

    // Dynamic Type scales the geometry-capped sizes instead of ignoring the
    // user's text-size setting.
    @ScaledMetric(relativeTo: .largeTitle) private var titleCap: CGFloat = 140
    @ScaledMetric(relativeTo: .body) private var taglineCap: CGFloat = 22

    private var titleTypeScale: CGFloat { titleCap / 140 }
    private var taglineTypeScale: CGFloat { taglineCap / 22 }

    /// The reference specifies this exact green, not the themed brand accent.
    private let referenceGreen = Color(
        red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255
    )

    var body: some View {
        ZStack {
            Image("Shuttlecock")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: SplashView.shuttleSize, height: SplashView.shuttleSize)
                .scaleEffect(CGFloat(pose.scale))
                .rotationEffect(.degrees(pose.rotation))
                .opacity(pose.opacity)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 40)

            VStack(spacing: 14) {
                Text("Smash")
                    .font(.system(size: min(layout.size.width * 0.22, 140) * titleTypeScale,
                                  weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 0) {
                    Text("Play it ")
                        .font(.system(size: min(layout.size.width * 0.04, 22) * taglineTypeScale,
                                      weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("smart")
                        .font(.system(size: min(layout.size.width * 0.04, 22) * taglineTypeScale,
                                      weight: .bold))
                        .foregroundStyle(referenceGreen)
                }
            }
            .multilineTextAlignment(.center)
            .scaleEffect(CGFloat(pose.textScale))
            .opacity(pose.textOpacity)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}

// MARK: - Preview

#Preview("Splash") {
    SplashView()
}
