import SwiftUI
import Softphone_Swift

#if VIDEO_FEATURE
struct CircularVideoButton: View {

    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: isSelected ? "video.slash.fill" : "video.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 56, height: 56)
                    .shadow(radius: 4)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: "video.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .green : .white)
                    .frame(width: 56, height: 56)
                    .background(isSelected ? Color.white : Color.green)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
    }
}

struct EndCallButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 56, height: 56)
                    .shadow(radius: 4)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
    }
}

@MainActor
final class InterfaceRotationObserver: ObservableObject {
    @Published var angle: Angle = .degrees(0)
    @Published var isQuarterTurn: Bool = false

    private var token: NSObjectProtocol?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        update()
        token = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.update() }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func update() {
        switch UIDevice.current.orientation {
        case .portrait:
            angle = .degrees(0); isQuarterTurn = false
        case .portraitUpsideDown:
            angle = .degrees(180); isQuarterTurn = false
        case .landscapeLeft:
            angle = .degrees(90); isQuarterTurn = true
        case .landscapeRight:
            angle = .degrees(-90); isQuarterTurn = true
        default: break
        }
    }
}

struct RotatingFitContainer<Content: View>: View {
    let angle: Angle
    let isQuarterTurn: Bool
    let bottomOverlap: CGFloat // Height of your button area
    let content: Content

    init(
        angle: Angle,
        isQuarterTurn: Bool,
        bottomOverlap: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.angle = angle
        self.isQuarterTurn = isQuarterTurn
        self.bottomOverlap = bottomOverlap
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let outer = proxy.size
            
            // 1. Calculate Shift
            // In portrait, shift Up by half the overlap to center the video in the "visible" area.
            // In landscape (quarter turn), do not shift.
            let yOffset = isQuarterTurn ? 0 : -(bottomOverlap / 2)

            // 2. Calculate Scale
            // When rotated 90deg, width becomes height. We scale down to fit letterbox style.
            let scale: CGFloat = {
                guard isQuarterTurn else { return 1 }
                let w = max(outer.width, 1)
                let h = max(outer.height, 1)
                return min(w / h, h / w)
            }()

            ZStack {
                content
            }
            // First, force the content to fill the screen bounds (before rotation)
            .frame(width: outer.width, height: outer.height)
            // Apply rotation
            .rotationEffect(angle)
            // Scale to fit screen logic
            .scaleEffect(scale, anchor: .center)
            // Apply vertical shift for buttons
            .offset(y: yOffset)
            // Ensure the frame stays strictly within bounds
            .frame(width: outer.width, height: outer.height)
            .clipped()
        }
    }
}

struct VideoScreenView: View {

    @StateObject var viewModel = VideoViewModel()
    @StateObject private var rotation = InterfaceRotationObserver()

    @State private var frame: CGRect = .zero
    private let previewSize = CGSize(width: 120, height: 180)
    private let vGridSpacing = 5.0
    
    // Height of your bottom control stack (Buttons + Spacing + Padding)
    private let bottomControlsHeight: CGFloat = 160

    var body: some View {
        ZStack(alignment: .bottom) {
            let calls = viewModel.callsWithVideos

            // -------- VIDEO LAYER --------
            if calls.isEmpty {
                VStack {
                    Spacer()
                    Text("No calls with video").foregroundColor(.secondary)
                    Spacer()
                }
            } else if calls.count == 1 {
                // SINGLE CALL MODE
                RotatingFitContainer(
                    angle: rotation.angle,
                    isQuarterTurn: rotation.isQuarterTurn,
                    bottomOverlap: bottomControlsHeight
                ) {
                    // Use Adaptive wrapper here
                    AdaptiveVideoView(callEvent: calls[0])
                }
                .background(Color.black)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: rotation.angle)

            } else {
                // GRID MODE
                ScrollView {
                    LazyVGrid(
                        columns: dynamicColumns(for: calls.count),
                        spacing: vGridSpacing
                    ) {
                        ForEach(calls, id: \.eventId) { callEvent in
                            RotatingFitContainer(
                                angle: rotation.angle,
                                isQuarterTurn: rotation.isQuarterTurn
                            ) {
                                AdaptiveVideoView(callEvent: callEvent)
                                    .background(Color.black)
                            }
                            .aspectRatio(1, contentMode: .fit) // Square cells
                            .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding()
                }
            }

            // -------- UI CONTROLS LAYER --------
            HStack(alignment: .bottom) {
                
                // PREVIEW (Left)
                if viewModel.isOutgoingVideoEnabled {
                    ZStack(alignment: .topTrailing) {
                        VideoPreviewRepresentable(
                            previewArea: CGRect(origin: .zero, size: previewSize),
                            reportedFrame: $frame
                        )
                        .frame(width: previewSize.width, height: previewSize.height)
                        .background(Color.black)
                        .cornerRadius(14)
                        .shadow(radius: 6)

                        Button {
                            viewModel.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(6)
                    }
                }

                Spacer()

                // CONTROLS (Right)
                VStack(spacing: 12) {
                    CircularVideoButton(
                        isSelected: viewModel.isOutgoingVideoEnabled,
                        action: { viewModel.toggleVideo() }
                    )

                    EndCallButton {
                        viewModel.endCall()
                    }
                }
            }
            .padding()
            // Ensure controls stay above the video layer
            .zIndex(1)
        }
    }

    private func dynamicColumns(for count: Int) -> [GridItem] {
        let columns = count <= 1 ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: vGridSpacing), count: columns)
    }
}
#endif
