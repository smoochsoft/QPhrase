import AppKit
import QuartzCore
import SwiftUI

/// Manages a floating overlay window that displays sparkle particle effects
/// near the cursor when QPhrase transformations are activated
class SparkleOverlayManager {
    static let shared = SparkleOverlayManager()

    // MARK: - Properties
    private var overlayWindow: NSWindow?
    private var emitterLayer: CAEmitterLayer?
    private var containerView: NSView?
    private var sparkleCell: CAEmitterCell?
    private var currentState: OverlayState = .hidden
    private var pulseAnimation: CABasicAnimation?

    enum OverlayState {
        case hidden
        case starting
        case processing
        case success
        case error
    }

    // MARK: - Initialization
    private init() {
        setupWindow()
        setupEmitter()
    }

    // MARK: - Public Methods

    /// Show the overlay at the specified location with the given state
    func showOverlay(at location: NSPoint, state: OverlayState, enabled: Bool = true) {
        guard enabled else { return }
        guard let window = overlayWindow else { return }

        positionWindow(at: location)
        currentState = state
        configureEmitter(for: state)

        window.orderFrontRegardless()
        window.alphaValue = 1.0

        // Auto-transition from starting to processing
        if state == .starting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if self?.currentState == .starting {
                    self?.transitionToState(.processing)
                }
            }
        }
    }

    /// Transition the overlay to a new state
    func transitionToState(_ state: OverlayState) {
        guard currentState != state else { return }

        currentState = state
        configureEmitter(for: state)

        // Auto-hide after success or error animations
        if state == .success || state == .error {
            let duration = state == .success ? 0.5 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.hideOverlay()
            }
        }
    }

    /// Hide the overlay window
    func hideOverlay() {
        guard let window = overlayWindow else { return }

        // Stop particle emission
        emitterLayer?.birthRate = 0
        currentState = .hidden

        // Remove pulsing animation
        emitterLayer?.removeAnimation(forKey: "pulse")
        emitterLayer?.transform = CATransform3DIdentity

        // Fade out window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    // MARK: - Private Setup Methods

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.alphaValue = 0

        // Create container view
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        view.wantsLayer = true
        view.layer = CALayer()
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.frame = view.bounds
        window.contentView = view

        containerView = view
        overlayWindow = window
    }

    private func setupEmitter() {
        guard let view = containerView, let layer = view.layer else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: 60, y: 60) // Center of 120x120 window
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 30, height: 30)
        emitter.renderMode = .additive // Creates glowing effect
        emitter.birthRate = 0 // Start hidden

        // Create sparkle particle cell
        let sparkleImage = createSparkleImage()

        let cell = CAEmitterCell()
        cell.contents = sparkleImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        cell.lifetime = 0.7
        cell.lifetimeRange = 0.2
        cell.velocity = 60
        cell.velocityRange = 40
        cell.emissionRange = .pi * 2 // 360 degrees
        cell.spin = 3
        cell.spinRange = 5
        cell.scale = 0.5
        cell.scaleRange = 0.2
        cell.scaleSpeed = -0.3
        cell.alphaSpeed = -1.2

        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)

        emitterLayer = emitter
        sparkleCell = cell
    }

    // MARK: - Configuration Methods

    private func configureEmitter(for state: OverlayState) {
        guard let emitter = emitterLayer, let cell = sparkleCell else { return }

        // Check for reduced motion accessibility setting
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if reduceMotion && state != .hidden {
            // Simple fade-in for accessibility
            emitter.birthRate = 0
            containerView?.layer?.opacity = 0

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                containerView?.animator().layer?.opacity = 1.0
            }
            return
        }

        // Remove any existing pulse animation
        emitter.removeAnimation(forKey: "pulse")
        emitter.transform = CATransform3DIdentity

        switch state {
        case .hidden:
            emitter.birthRate = 0

        case .starting:
            // Small circular burst - blue/cyan
            emitter.birthRate = 150
            cell.birthRate = 1
            cell.color = NSColor.systemBlue.cgColor
            cell.velocity = 80
            cell.scale = 0.45

        case .processing:
            // Continuous gentle sparkle ring - purple
            emitter.birthRate = 40
            cell.birthRate = 1
            cell.color = NSColor.systemPurple.cgColor
            cell.velocity = 50
            cell.scale = 0.4

            // Add pulsing scale animation
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.9
            pulse.toValue = 1.1
            pulse.duration = 1.0
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            emitter.add(pulse, forKey: "pulse")

        case .success:
            // Large celebratory burst - green/gold
            emitter.birthRate = 250
            cell.birthRate = 1
            cell.color = NSColor.systemGreen.cgColor
            cell.velocity = 100
            cell.scale = 0.6
            cell.scaleSpeed = -0.2

            // Quick scale-up for impact
            let scaleUp = CABasicAnimation(keyPath: "transform.scale")
            scaleUp.fromValue = 0.8
            scaleUp.toValue = 1.2
            scaleUp.duration = 0.15
            scaleUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
            emitter.add(scaleUp, forKey: "scaleUp")

        case .error:
            // Brief red flash - red/orange
            emitter.birthRate = 100
            cell.birthRate = 1
            cell.color = NSColor.systemRed.cgColor
            cell.velocity = 70
            cell.scale = 0.45
            cell.lifetime = 0.5
        }
    }

    private func positionWindow(at location: NSPoint) {
        guard let window = overlayWindow else { return }

        // Find the screen containing the cursor
        let targetScreen = NSScreen.screens.first { screen in
            NSPointInRect(location, screen.frame)
        } ?? NSScreen.main

        guard let screen = targetScreen else { return }

        // Offset window: 20pt right, 30pt down from cursor
        // Note: AppKit uses bottom-left origin
        var targetX = location.x + 20
        var targetY = location.y - 30

        let windowSize = window.frame.size

        // Clamp to screen bounds (with 10pt margin)
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 10

        if targetX + windowSize.width + margin > screenFrame.maxX {
            targetX = screenFrame.maxX - windowSize.width - margin
        }
        if targetX < screenFrame.minX + margin {
            targetX = screenFrame.minX + margin
        }
        if targetY < screenFrame.minY + margin {
            targetY = screenFrame.minY + margin
        }
        if targetY + windowSize.height + margin > screenFrame.maxY {
            targetY = screenFrame.maxY - windowSize.height - margin
        }

        window.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }

    private func createSparkleImage() -> NSImage {
        let size = CGSize(width: 12, height: 12)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw a 4-pointed star
        let path = NSBezierPath()
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outerRadius: CGFloat = 6
        let innerRadius: CGFloat = 2.5

        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }
        path.close()

        // White fill for particle (color applied via CAEmitterCell)
        NSColor.white.setFill()
        path.fill()

        image.unlockFocus()
        return image
    }
}
