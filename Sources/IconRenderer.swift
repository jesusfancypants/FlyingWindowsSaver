import AppKit

enum IconMode: String, CaseIterable, Identifiable {
    case windowsFlag
    case appleLogo
    case emoji

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .windowsFlag: return "Windows Flag"
        case .appleLogo: return "Apple Logo"
        case .emoji: return "Emoji"
        }
    }
}

enum IconRenderer {
    /// The classic waving-flag Windows logo, as traced in the Wingdings font.
    /// Path data from https://upload.wikimedia.org/wikipedia/commons/6/64/Microsoft_Logo_Wingdings_Font.svg
    /// (single color in the original; we render it as an alpha mask and tint
    /// it per-object, since the original screen saver assigned each flying
    /// icon a random solid color rather than the fixed 4-color logo).
    // Trailing "M 1957,20 ... Z" glyph from the source SVG (a small decorative
    // mark far to the right of the flag) is intentionally dropped — its
    // presence would skew the bounding-box fit used to center/scale the flag.
    private static let windowsFlagPathData = "m 168,1415 v -59 l -68,-28 v 58 z m -7,-191 v -53 l -55,-25 v 52 z m 0,-192 v -52 l -55,-25 v 52 z m 7,-189 v -59 l -68,-28 v 57 z m -7,-199 v -51 l -55,-25 v 52 z m 0,-194 v -52 l -55,-25 v 51 z m 7,-187 v -60 l -68,-28 v 57 z m 172,1119 v -69 l -92,-35 v 68 z m -5,-200 v -63 l -74,-29 v 63 z m 0,-193 v -62 l -74,-29 v 64 z m 5,-186 v -68 l -92,-36 v 68 z m -5,-200 v -62 l -74,-30 v 64 z m 0,-195 v -62 l -74,-30 v 63 z m 5,-187 v -68 l -92,-38 v 68 z m 172,1118 v -82 l -119,-47 v 81 z m -6,-201 v -73 l -100,-39 v 71 z m 0,-193 V 873 L 406,833 v 72 z m 6,-185 V 678 L 393,631 v 81 z M 506,559 V 487 L 406,446 v 72 z m 0,-187 V 298 L 406,258 v 72 z m 6,-187 V 103 L 393,55 v 82 z m 188,1159 v -108 l -149,-60 v 107 z m -8,-201 v -99 L 567,993 v 99 z m 0,-193 V 852 L 567,801 v 99 z m 8,-186 V 656 L 551,597 V 705 Z M 692,563 V 464 L 567,414 v 99 z m 0,-187 V 277 L 567,227 v 98 z m 8,-186 V 82 L 551,22 v 107 z m 197,1172 v -141 l -166,-68 v 141 z m -8,-212 V 1032 L 747,975 v 119 z m 0,-184 V 847 L 747,791 v 118 z m 8,-183 V 642 L 731,575 V 716 Z M 889,572 V 452 L 747,397 v 118 z m 0,-188 V 265 L 747,208 v 119 z m 8,-176 V 67 L 731,0 v 141 z m 201,1225 v -193 l -177,-74 v 180 q 92,53 177,87 z m 0,-213 V 1053 L 921,978 v 168 z m 0,-188 V 863 L 921,788 v 169 z m 0,-190 V 675 L 921,600 v 168 z m 0,-188 V 482 L 921,406 v 173 z m 0,-193 V 293 L 921,216 v 170 z m 0,-189 V 92 Q 994,52 921,15 v 181 z m 920,1154 V 75 q -171,112 -427,112 -212,0 -474,-88 v 180 q 139,55 306,79 v 440 q -141,-18 -306,-98 v 129 q 143,66 306,90 v 427 q -147,-28 -306,-95 v 190 q 233,95 457,95 241,0 444,-110 z m -177,-121 q -111,56 -266,56 -18,0 -36,-2 V 927 l 40,1 q 133,0 262,-42 z m 0,-547 q -119,52 -264,52 -18,0 -38,-2 V 368 h 40 q 145,0 262,-36 z"

    /// The SVG's group applies `matrix(1,0,0,-1,-110,1536)` to the raw glyph
    /// path before it lands in the (Y-down) viewBox.
    private static let windowsFlagPath: CGPath = {
        let raw = SVGPath.parse(windowsFlagPathData)
        var groupTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: -110, ty: 1536)
        return raw.copy(using: &groupTransform) ?? raw
    }()

    /// A spread of fully-saturated hues, matching the "random solid color
    /// per flying icon" look of the original screen saver's Windows object.
    static let randomColorPalette: [NSColor] = (0..<FlyingObject.colorPaletteSize).map { i in
        NSColor(hue: CGFloat(i) / CGFloat(FlyingObject.colorPaletteSize), saturation: 0.85, brightness: 0.95, alpha: 1.0)
    }

    static func windowsFlagMask(reference: CGFloat = 256) -> CGImage {
        let fit = SVGPath.fittingTransform(for: windowsFlagPath, reference: reference)
        let fitted = SVGPath.transformed(windowsFlagPath, by: fit)
        let image = NSImage(size: NSSize(width: reference, height: reference), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(fitted)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillPath(using: .winding)
            return true
        }
        return cgImage(from: image, reference: reference)
    }

    /// Composites a solid color through a mask's alpha channel.
    static func tinted(mask: CGImage, color: NSColor, reference: CGFloat = 256) -> CGImage {
        let canvas = NSImage(size: NSSize(width: reference, height: reference))
        canvas.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: reference, height: reference))
            ctx.setBlendMode(.destinationIn)
            ctx.draw(mask, in: CGRect(x: 0, y: 0, width: reference, height: reference))
        }
        canvas.unlockFocus()
        return cgImage(from: canvas, reference: reference)
    }

    /// One flat image per icon mode, used for modes that don't need
    /// per-object color variation (everything except the Windows flag,
    /// which is rendered via `windowsFlagMask` + `tinted`).
    static func templateImage(mode: IconMode, emoji: String, reference: CGFloat = 256) -> CGImage {
        switch mode {
        case .windowsFlag:
            return tinted(mask: windowsFlagMask(reference: reference), color: .white, reference: reference)
        case .appleLogo:
            return cgImage(from: renderAppleLogo(reference: reference), reference: reference)
        case .emoji:
            return cgImage(from: renderEmoji(emoji, reference: reference), reference: reference)
        }
    }

    private static func cgImage(from image: NSImage, reference: CGFloat) -> CGImage {
        var rect = NSRect(x: 0, y: 0, width: reference, height: reference)
        if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }
        return windowsFlagMask(reference: reference)
    }

    private static func renderAppleLogo(reference: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: reference * 0.72, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return NSImage(size: NSSize(width: reference, height: reference))
        }
        let canvas = NSImage(size: NSSize(width: reference, height: reference))
        canvas.lockFocus()
        let symbolSize = symbol.size
        let origin = NSPoint(x: (reference - symbolSize.width) / 2, y: (reference - symbolSize.height) / 2)
        let destRect = NSRect(origin: origin, size: symbolSize)
        NSColor.white.setFill()
        NSBezierPath(rect: destRect).fill()
        symbol.draw(in: destRect, from: .zero, operation: .destinationIn, fraction: 1.0)
        canvas.unlockFocus()
        return canvas
    }

    private static func renderEmoji(_ emoji: String, reference: CGFloat) -> NSImage {
        let str = emoji.isEmpty ? "🪟" : emoji
        let canvas = NSImage(size: NSSize(width: reference, height: reference))
        canvas.lockFocus()
        let font = NSFont.systemFont(ofSize: reference * 0.78)
        let attrStr = NSAttributedString(string: str, attributes: [.font: font])
        let strSize = attrStr.size()
        let origin = NSPoint(x: (reference - strSize.width) / 2, y: (reference - strSize.height) / 2)
        attrStr.draw(at: origin)
        canvas.unlockFocus()
        return canvas
    }
}
