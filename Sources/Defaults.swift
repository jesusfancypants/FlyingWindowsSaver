import ScreenSaver

final class Defaults {
    static let moduleName = "com.rezo.FlyingWindowsSaver"

    private let d: ScreenSaverDefaults

    init() {
        guard let d = ScreenSaverDefaults(forModuleWithName: Self.moduleName) else {
            fatalError("ScreenSaverDefaults init failed for \(Self.moduleName)")
        }
        d.register(defaults: [
            "iconMode": IconMode.windowsFlag.rawValue,
            "objectCount": 20,
            "speedMultiplier": 1.0,
            "rotationEnabled": false,
            "emoji": "🪟",
        ])
        self.d = d
    }

    var iconMode: IconMode {
        get { IconMode(rawValue: d.string(forKey: "iconMode") ?? "") ?? .windowsFlag }
        set {
            d.set(newValue.rawValue, forKey: "iconMode")
            d.synchronize()
        }
    }

    var objectCount: Int {
        get { min(60, max(1, d.integer(forKey: "objectCount"))) }
        set {
            d.set(min(60, max(1, newValue)), forKey: "objectCount")
            d.synchronize()
        }
    }

    var speedMultiplier: Double {
        get {
            let v = d.double(forKey: "speedMultiplier")
            return v == 0 ? 1.0 : min(5.0, max(0.1, v))
        }
        set {
            d.set(min(5.0, max(0.1, newValue)), forKey: "speedMultiplier")
            d.synchronize()
        }
    }

    var rotationEnabled: Bool {
        get { d.bool(forKey: "rotationEnabled") }
        set {
            d.set(newValue, forKey: "rotationEnabled")
            d.synchronize()
        }
    }

    var emoji: String {
        get { d.string(forKey: "emoji") ?? "🪟" }
        set {
            d.set(newValue, forKey: "emoji")
            d.synchronize()
        }
    }
}
