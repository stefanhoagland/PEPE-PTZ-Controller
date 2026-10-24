import PTZCore
import SwiftUI

/// The live picture for a camera, or a moving test pattern for a simulated one.
struct LiveVideoView: View {
    let camera: Camera

    var body: some View {
        Group {
            if camera.isSimulated {
                TestPatternView()
            } else {
                CameraVideoView(camera: camera)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CameraVideoView: View {
    @StateObject private var model: LiveVideoModel
    @AppStorage("videoMode") private var mode: LiveVideoModel.Mode = .stream

    init(camera: Camera) {
        _model = StateObject(wrappedValue: LiveVideoModel(
            camera: camera,
            password: Keychain.password(for: camera.id)
        ))
    }

    var body: some View {
        ZStack {
            Color.black
            if let frame = model.frame {
                Image(frame, scale: 1, label: Text("Live view"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            if mode == .off {
                Label("Video off", systemImage: "video.slash")
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                statusOverlay
            }
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Picker("Video", selection: $mode) {
                    ForEach(LiveVideoModel.Mode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Video: \(mode.label)", systemImage: "video")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
            .foregroundStyle(.white)
            .padding(8)
            .help("Stream is smoothest. Snapshots or Off leave the camera more room for control commands.")
        }
        .onAppear { model.start(mode: mode) }
        .onDisappear { model.stop() }
        .onChange(of: mode) { newMode in model.start(mode: newMode) }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.status {
        case .live:
            EmptyView()
        case .connecting:
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting to video…")
            }
            .padding(12)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        case let .failed(message):
            VStack(spacing: 6) {
                Image(systemName: "video.slash").font(.title)
                Text(message).multilineTextAlignment(.center)
                Text("Retrying…").font(.caption).opacity(0.7)
            }
            .padding(12)
            .frame(maxWidth: 360)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }
    }
}

/// Color bars with a moving marker and a clock, so you can see the view is live.
private struct TestPatternView: View {
    private static let bars: [Color] = [.white, .yellow, .cyan, .green, .pink, .red, .blue]

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let width = size.width / CGFloat(Self.bars.count)
                for (index, color) in Self.bars.enumerated() {
                    let rect = CGRect(x: CGFloat(index) * width, y: 0, width: width + 1, height: size.height * 0.75)
                    canvas.fill(Path(rect), with: .color(color.opacity(0.8)))
                }
                canvas.fill(
                    Path(CGRect(x: 0, y: size.height * 0.75, width: size.width, height: size.height * 0.25)),
                    with: .color(.black)
                )

                let seconds = context.date.timeIntervalSinceReferenceDate
                let x = (sin(seconds) * 0.45 + 0.5) * size.width
                let marker = CGRect(x: x - 12, y: size.height * 0.375 - 12, width: 24, height: 24)
                canvas.fill(Path(ellipseIn: marker), with: .color(.black))

                let clock = Text(context.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: max(12, size.height * 0.08), weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                canvas.draw(clock, at: CGPoint(x: size.width / 2, y: size.height * 0.875))
            }
        }
        .overlay(alignment: .topLeading) {
            Text("SIMULATED")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.6), in: Capsule())
                .foregroundStyle(.white)
                .padding(8)
        }
    }
}
