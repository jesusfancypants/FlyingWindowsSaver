import AppKit
import ScreenSaver
import QuartzCore

extension Notification.Name {
    static let fwInstanceAnnounced = Notification.Name("FlyingWindowsSaver.instanceAnnounced")
}

@objc(FlyingWindowsView)
final class FlyingWindowsView: ScreenSaverView {
    private let instanceID = UUID()
    private var isLameDuck = false
    private var internalTimer: Timer?
    private var lastTick: CFTimeInterval = 0
    private var objects: [FlyingObject] = []
    private var iconVariants: [CGImage] = []
    private let defaults = Defaults()
    private var configureController: ConfigureSheetController?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 30.0
        applySettings(scattered: true)

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAnnouncement(_:)),
            name: .fwInstanceAnnounced, object: nil
        )
        NotificationCenter.default.post(
            name: .fwInstanceAnnounced, object: nil,
            userInfo: ["id": instanceID]
        )

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleWillStop),
            name: NSNotification.Name("com.apple.screensaver.willstop"), object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        internalTimer?.invalidate()
    }

    @objc private func handleAnnouncement(_ note: Notification) {
        guard let id = note.userInfo?["id"] as? UUID, id != instanceID else { return }
        isLameDuck = true
        internalTimer?.invalidate()
        internalTimer = nil
        removeFromSuperview()
    }

    @objc private func handleWillStop() {
        internalTimer?.invalidate()
        internalTimer = nil
        // The System Settings live-preview thumbnail shares System Settings'
        // own process (isPreview == true there); never exit that process.
        guard !isLameDuck, !isPreview else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            exit(0)
        }
    }

    override func startAnimation() {
        super.startAnimation()
        guard !isLameDuck else { return }
        lastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: animationTimeInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        internalTimer = timer
    }

    override func stopAnimation() {
        super.stopAnimation()
        internalTimer?.invalidate()
        internalTimer = nil
    }

    override func animateOneFrame() {
        tick()
    }

    private func tick() {
        guard !isLameDuck else { return }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        let speed: CGFloat = 4.0 * CGFloat(defaults.speedMultiplier)
        let rotating = defaults.rotationEnabled
        for i in objects.indices {
            objects[i].update(dt: CGFloat(dt), unitsPerSecond: speed, rotating: rotating)
        }
        setNeedsDisplay(bounds)
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
        guard let ctx = NSGraphicsContext.current?.cgContext, !iconVariants.isEmpty else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let spread = hypot(bounds.width, bounds.height) / 2
        let baseIconSize: CGFloat = 48

        for obj in objects.sorted(by: { $0.z > $1.z }) {
            let p = obj.position(center: center, spreadRadius: spread)
            let size = baseIconSize * obj.scale()
            let image = iconVariants[obj.colorIndex % iconVariants.count]
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            ctx.rotate(by: obj.rotation)
            ctx.draw(image, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            ctx.restoreGState()
        }
    }

    /// Rebuilds the object pool and icon image variants from current
    /// defaults. `scattered` places existing/new objects at random depths
    /// (used on first launch); pass `false` to only respawn newly added
    /// objects far away, keeping already-flying objects undisturbed.
    func applySettings(scattered: Bool) {
        if defaults.iconMode == .windowsFlag {
            let mask = IconRenderer.windowsFlagMask()
            iconVariants = IconRenderer.randomColorPalette.map { IconRenderer.tinted(mask: mask, color: $0) }
        } else {
            iconVariants = [IconRenderer.templateImage(mode: defaults.iconMode, emoji: defaults.emoji)]
        }

        let targetCount = defaults.objectCount
        if objects.count > targetCount {
            objects.removeLast(objects.count - targetCount)
        } else if objects.count < targetCount {
            let toAdd = targetCount - objects.count
            objects.append(contentsOf: (0..<toAdd).map { _ in FlyingObject.spawn(scattered: scattered) })
        } else if scattered {
            objects = (0..<targetCount).map { _ in FlyingObject.spawn(scattered: true) }
        }
    }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        if configureController == nil {
            configureController = ConfigureSheetController(defaults: defaults) { [weak self] window in
                window.sheetParent?.endSheet(window)
                self?.applySettings(scattered: false)
            }
        }
        return configureController?.window
    }
}
