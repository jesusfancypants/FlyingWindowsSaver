import CoreGraphics

struct FlyingObject {
    static let farZ: CGFloat = 20.0
    static let nearZ: CGFloat = 0.6
    static let focalLength: CGFloat = 6.0

    /// Number of distinct random colors available for the Windows-flag icon,
    /// matching the original screen saver assigning each flying icon its own
    /// random solid color. Kept here (rather than in IconRenderer) so this
    /// file stays framework-agnostic; IconRenderer builds its color palette
    /// to match this count.
    static let colorPaletteSize = 16

    var dx: CGFloat
    var dy: CGFloat
    var z: CGFloat
    var rotation: CGFloat
    var rotationRate: CGFloat
    var colorIndex: Int

    static func spawn(scattered: Bool) -> FlyingObject {
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        let r = sqrt(CGFloat.random(in: 0...1))
        let z = scattered ? CGFloat.random(in: nearZ...farZ) : farZ
        return FlyingObject(
            dx: cos(angle) * r,
            dy: sin(angle) * r,
            z: z,
            rotation: 0,
            rotationRate: CGFloat.random(in: -1.5...1.5),
            colorIndex: Int.random(in: 0..<colorPaletteSize)
        )
    }

    mutating func update(dt: CGFloat, unitsPerSecond: CGFloat, rotating: Bool) {
        z -= unitsPerSecond * dt
        if rotating {
            rotation += rotationRate * dt
        }
        if z <= Self.nearZ {
            self = Self.spawn(scattered: false)
        }
    }

    func scale(focalLength: CGFloat = FlyingObject.focalLength) -> CGFloat {
        focalLength / z
    }

    func position(center: CGPoint, spreadRadius: CGFloat, focalLength: CGFloat = FlyingObject.focalLength) -> CGPoint {
        let s = scale(focalLength: focalLength)
        return CGPoint(x: center.x + dx * spreadRadius * s, y: center.y + dy * spreadRadius * s)
    }
}
