import CoreGraphics

/// Minimal parser for the subset of the SVG path `d` mini-language actually
/// used by the reference glyph we embed (M/m, L/l, V/v, H/h, Q/q, Z/z, in
/// both absolute and relative form, including SVG's implicit-command-repeat
/// rule). Not a general-purpose SVG path parser.
enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let chars = Array(d)
        var i = 0
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCommand: Character = " "
        let commandChars = Set("MmLlVvHhQqZz")

        func skipSeparators() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" {
                i += 1
            }
        }

        func readNumber() -> CGFloat? {
            skipSeparators()
            var j = i
            if j < chars.count, chars[j] == "-" || chars[j] == "+" { j += 1 }
            var sawDigits = false
            while j < chars.count, chars[j].isNumber || chars[j] == "." {
                sawDigits = true
                j += 1
            }
            guard sawDigits, j > i else { return nil }
            let s = String(chars[i..<j])
            i = j
            return CGFloat(Double(s) ?? 0)
        }

        while i < chars.count {
            skipSeparators()
            guard i < chars.count else { break }
            let cmd: Character
            if commandChars.contains(chars[i]) {
                cmd = chars[i]
                i += 1
                lastCommand = cmd
            } else {
                cmd = lastCommand
            }

            switch cmd {
            case "M", "m":
                guard let x = readNumber(), let y = readNumber() else { return path }
                current = cmd == "m" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.move(to: current)
                subpathStart = current
                lastCommand = (cmd == "m") ? "l" : "L"
            case "L", "l":
                guard let x = readNumber(), let y = readNumber() else { return path }
                current = cmd == "l" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addLine(to: current)
            case "V", "v":
                guard let y = readNumber() else { return path }
                current = cmd == "v" ? CGPoint(x: current.x, y: current.y + y) : CGPoint(x: current.x, y: y)
                path.addLine(to: current)
            case "H", "h":
                guard let x = readNumber() else { return path }
                current = cmd == "h" ? CGPoint(x: current.x + x, y: current.y) : CGPoint(x: x, y: current.y)
                path.addLine(to: current)
            case "Q", "q":
                guard let cx = readNumber(), let cy = readNumber(), let x = readNumber(), let y = readNumber() else { return path }
                let ctrl: CGPoint
                let end: CGPoint
                if cmd == "q" {
                    ctrl = CGPoint(x: current.x + cx, y: current.y + cy)
                    end = CGPoint(x: current.x + x, y: current.y + y)
                } else {
                    ctrl = CGPoint(x: cx, y: cy)
                    end = CGPoint(x: x, y: y)
                }
                path.addQuadCurve(to: end, control: ctrl)
                current = end
            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
            default:
                return path
            }
        }
        return path
    }

    /// Applies an arbitrary CGAffineTransform to every point in a path.
    static func transformed(_ path: CGPath, by transform: CGAffineTransform) -> CGPath {
        var t = transform
        return path.copy(using: &t) ?? path
    }

    /// Builds a transform that fits `path`'s bounding box into a
    /// `reference`x`reference` square, centered, filling `fill` fraction of
    /// it, flipping Y (SVG is Y-down; our render contexts are Y-up).
    static func fittingTransform(for path: CGPath, reference: CGFloat, fill: CGFloat = 0.86) -> CGAffineTransform {
        let box = path.boundingBoxOfPath
        guard box.width > 0, box.height > 0 else { return .identity }
        let scale = min(reference * fill / box.width, reference * fill / box.height)
        let cx = box.midX
        let cy = box.midY
        return CGAffineTransform(
            a: scale, b: 0, c: 0, d: -scale,
            tx: reference / 2 - scale * cx,
            ty: reference / 2 + scale * cy
        )
    }
}
