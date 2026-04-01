import AppKit

/// Observes the titlebar container and re-centers traffic light buttons
/// to match a target height (e.g. 44pt tab bar) on every layout change.
@MainActor
final class TrafficLightAligner {
    private let targetHeight: CGFloat
    private weak var window: NSWindow?
    private var frameObservation: NSObjectProtocol?

    init(window: NSWindow, targetHeight: CGFloat) {
        self.window = window
        self.targetHeight = targetHeight

        guard let closeButton = window.standardWindowButton(.closeButton),
              let container = closeButton.superview else { return }

        // Observe container frame changes to re-center after system layout
        container.postsFrameChangedNotifications = true
        frameObservation = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: container,
            queue: .main
        ) { [weak self] _ in
            self?.realign()
        }

        // Initial alignment after first layout
        DispatchQueue.main.async { [weak self] in
            self?.realign()
        }
    }

    func tearDown() {
        if let obs = frameObservation {
            NotificationCenter.default.removeObserver(obs)
            frameObservation = nil
        }
    }

    func realign() {
        guard let window, let contentView = window.contentView else { return }
        guard let closeButton = window.standardWindowButton(.closeButton),
              let container = closeButton.superview else { return }

        // Prevent the titlebar container from clipping repositioned buttons
        container.wantsLayer = true
        container.layer?.masksToBounds = false

        let buttonHeight = closeButton.frame.height
        // Equal margin from top and left edges of the window
        let margin = (targetHeight - buttonHeight) / 2

        // Convert desired close-button origin from content-view coords to container coords.
        // NSHostingView is flipped (y=0 at top): x=margin is from the left edge,
        // y=margin is from the top edge (button top, not center).
        let desiredOrigin = contentView.convert(
            NSPoint(x: margin, y: margin),
            to: container
        )

        // Shift all three buttons so close button lands at the desired origin
        let xShift = desiredOrigin.x - closeButton.frame.origin.x
        let desiredCenterY = contentView.convert(
            NSPoint(x: 0, y: targetHeight / 2),
            to: container
        ).y

        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for type in buttonTypes {
            guard let button = window.standardWindowButton(type) else { continue }

            let desiredY = desiredCenterY - button.frame.height / 2
            if abs(button.frame.origin.y - desiredY) > 0.5 {
                button.frame.origin.y = desiredY
            }

            let desiredX = button.frame.origin.x + xShift
            if abs(button.frame.origin.x - desiredX) > 0.5 {
                button.frame.origin.x = desiredX
            }
        }
    }
}
