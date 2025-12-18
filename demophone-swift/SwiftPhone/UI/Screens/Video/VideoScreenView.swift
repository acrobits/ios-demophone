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
    @Published var isQuarterTurn: Bool = false   // true for +/- 90 degrees

    private var token: NSObjectProtocol?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        update()

        token = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.update()
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func update() {
//        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let orientation = UIDevice.current.orientation

        switch orientation {
        case .portrait:
            angle = .degrees(0)
            isQuarterTurn = false
        case .portraitUpsideDown:
            angle = .degrees(180)
            isQuarterTurn = false
        case .landscapeLeft:
            angle = .degrees(90)
            isQuarterTurn = true
        case .landscapeRight:
            angle = .degrees(-90)
            isQuarterTurn = true
        default:
            break // keep current
        }
    }
}

struct RotatingFitContainer<Content: View>: View {
    let angle: Angle
    let isQuarterTurn: Bool
    let content: Content

    init(angle: Angle, isQuarterTurn: Bool, @ViewBuilder content: () -> Content) {
        self.angle = angle
        self.isQuarterTurn = isQuarterTurn
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let outer = proxy.size

            // If we rotate 90°/270°, the rotated bounding box swaps width/height.
            // Scale down so it *fits* (letterbox) instead of cropping.
            let scale: CGFloat = {
                guard isQuarterTurn else { return 1 }
                let w = max(outer.width, 1)
                let h = max(outer.height, 1)
                return min(w / h, h / w) // always <= 1
            }()

            content
                .frame(width: outer.width, height: outer.height)
                .rotationEffect(angle)
                .scaleEffect(scale, anchor: .center)
                .frame(width: outer.width, height: outer.height)
                .clipped()
        }
    }
}

import SwiftUI

struct VideoScreenView: View {

    @StateObject var viewModel = VideoViewModel()
    @StateObject private var rotation = InterfaceRotationObserver()

    @State private var frame: CGRect = .zero

    // eventId -> (width/height)
    @State private var aspectRatios: [AnyHashable: CGFloat] = [:]

    private let previewSize = CGSize(width: 120, height: 180)
    private let vGridSpacing = 5.0

    var body: some View {
        ZStack(alignment: .bottom) {
            let calls = viewModel.callsWithVideos

            if calls.isEmpty {
                VStack {
                    Spacer()
                    Text("No calls with video")
                        .foregroundColor(.secondary)
                        .font(.headline)
                    Spacer()
                }
            } else if calls.count == 1 {
                Color.black.ignoresSafeArea()
                
                let call = calls[0]

                RotatingFitContainer(angle: rotation.angle, isQuarterTurn: rotation.isQuarterTurn) {
                    incomingVideo(for: call)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: rotation.angle)

            } else {
                Color.black.ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: dynamicColumns(for: calls.count), spacing: vGridSpacing) {
                        ForEach(calls, id: \.eventId) { call in
                            RotatingFitContainer(angle: rotation.angle, isQuarterTurn: rotation.isQuarterTurn) {
                                incomingVideo(for: call)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .mask(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .animation(.easeInOut(duration: 0.25), value: rotation.angle)
                        }
                    }
                    .padding()
                }
            }

            // -------- BOTTOM OVERLAYS (LEFT + RIGHT) --------
            HStack(alignment: .bottom) {

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
        }
    }

    // MARK: - Incoming video

    private func incomingVideo(for call: SoftphoneCallEvent) -> some View {
        let key = AnyHashable(call.eventId)

        return ZStack {
            Color.black // letterbox bars

            VideoViewRepresentable(
                callEvent: call,
                videoAspectRatio: Binding<CGFloat?>(
                    get: { aspectRatios[key] },
                    set: { newValue in
                        guard let r = newValue, r.isFinite, r > 0 else { return }
                        aspectRatios[key] = r
                    }
                )
            )
            // Host view handles aspect-fit; just fill available space
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dynamicColumns(for count: Int) -> [GridItem] {
        let columns = count <= 1 ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: vGridSpacing), count: columns)
    }
}

#endif
