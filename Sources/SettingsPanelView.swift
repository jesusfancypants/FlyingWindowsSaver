import AppKit

/// Plain AppKit settings UI (no SwiftUI/Combine, for the fewest possible
/// runtime dependencies) hosted inside the screen saver's own "Options…"
/// configure sheet — see `ConfigureSheetController`.
final class SettingsPanelView: NSView {
    private let defaults: Defaults
    var onDone: (() -> Void)?
    /// Called whenever this view's own fitting size changes (e.g. the emoji
    /// field appearing/disappearing) so the hosting window can resize to match.
    var onLayoutChange: (() -> Void)?

    private let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let emojiField = NSTextField(string: "")
    private let countValueLabel = NSTextField(labelWithString: "")
    private let countSlider = NSSlider(value: 20, minValue: 1, maxValue: 60, target: nil, action: nil)
    private let speedValueLabel = NSTextField(labelWithString: "")
    private let speedSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 5.0, target: nil, action: nil)
    private let rotationCheckbox = NSButton(checkboxWithTitle: "Rotate icons", target: nil, action: nil)

    /// Width shared by the popup, emoji field, and button row. The
    /// label-plus-slider rows are sized so their total width matches this
    /// exactly (label + spacing + slider), so every row lines up.
    private let rowWidth: CGFloat = 300
    private let labelWidth: CGFloat = 90
    private let rowSpacing: CGFloat = 8

    private var selfWidthConstraint: NSLayoutConstraint!
    private var selfHeightConstraint: NSLayoutConstraint!

    init(defaults: Defaults) {
        self.defaults = defaults
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 300))
        buildUI()
        loadFromDefaults()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        let title = NSTextField(labelWithString: "Flying Windows")
        title.font = .boldSystemFont(ofSize: 15)

        iconPopup.removeAllItems()
        iconPopup.addItems(withTitles: IconMode.allCases.map(\.displayName))
        iconPopup.target = self
        iconPopup.action = #selector(iconChanged)

        emojiField.placeholderString = "Type or paste an emoji, e.g. 😀"
        emojiField.delegate = self
        emojiField.target = self
        emojiField.action = #selector(emojiChanged)
        emojiField.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
        // Set visibility before the initial fitting-size snapshot below, so
        // a hidden field doesn't leave a gap that autolayout then stretches
        // to fill (it was reserving space for a control fixed at build time).
        emojiField.isHidden = defaults.iconMode != .emoji

        countSlider.target = self
        countSlider.action = #selector(countChanged)
        countSlider.setContentHuggingPriority(.required, for: .horizontal)
        let countStack = NSStackView(views: [countValueLabel, countSlider])
        countStack.orientation = .horizontal
        countStack.distribution = .equalSpacing
        countStack.spacing = rowSpacing
        countStack.setContentHuggingPriority(.required, for: .horizontal)
        countValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        countValueLabel.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        countStack.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true

        speedSlider.target = self
        speedSlider.action = #selector(speedChanged)
        speedSlider.setContentHuggingPriority(.required, for: .horizontal)
        let speedStack = NSStackView(views: [speedValueLabel, speedSlider])
        speedStack.orientation = .horizontal
        speedStack.distribution = .equalSpacing
        speedStack.spacing = rowSpacing
        speedStack.setContentHuggingPriority(.required, for: .horizontal)
        speedValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        speedValueLabel.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        speedStack.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true

        let sliderWidth = rowWidth - labelWidth - rowSpacing
        countSlider.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true
        speedSlider.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true

        rotationCheckbox.target = self
        rotationCheckbox.action = #selector(rotationChanged)

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [NSView(), doneButton])
        buttonRow.orientation = .horizontal
        buttonRow.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true

        iconPopup.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true

        let stack = NSStackView(views: [
            title, iconPopup, emojiField, countStack, speedStack, rotationCheckbox, buttonRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Lock this view's own size to the stack's fitting size with an
        // explicit, required constraint (kept live in `selfWidthConstraint`/
        // `selfHeightConstraint` so `refitSize()` can update it later) —
        // not just a bare `frame.size` assignment. A plain frame assignment
        // can get silently overridden once this view becomes a real
        // window's contentView (the window resizes its contentView to its
        // own content rect), which is what was letting the sliders stretch
        // to fill whatever width the host window ended up with. A hard
        // width/height constraint on self can't be overridden that way.
        translatesAutoresizingMaskIntoConstraints = false
        selfWidthConstraint = widthAnchor.constraint(equalToConstant: 380)
        selfHeightConstraint = heightAnchor.constraint(equalToConstant: 300)
        selfWidthConstraint.isActive = true
        selfHeightConstraint.isActive = true

        refitSize()
    }

    /// Recomputes this view's fitting size (with the self-size constraints
    /// temporarily relaxed so they don't just echo their own last value)
    /// and applies it, then notifies `onLayoutChange` so the hosting window
    /// can resize to match. Needed because toggling the emoji field's
    /// visibility changes how much space the content actually needs — the
    /// window has to grow to fit it, otherwise the field is present but
    /// clipped/unusable.
    private func refitSize() {
        selfWidthConstraint.isActive = false
        selfHeightConstraint.isActive = false
        layoutSubtreeIfNeeded()
        let fitted = fittingSize
        selfWidthConstraint.constant = max(380, fitted.width)
        selfHeightConstraint.constant = max(300, fitted.height)
        selfWidthConstraint.isActive = true
        selfHeightConstraint.isActive = true
        layoutSubtreeIfNeeded()
        onLayoutChange?()
    }

    private func loadFromDefaults() {
        iconPopup.selectItem(at: IconMode.allCases.firstIndex(of: defaults.iconMode) ?? 0)
        countSlider.doubleValue = Double(defaults.objectCount)
        speedSlider.doubleValue = defaults.speedMultiplier
        rotationCheckbox.state = defaults.rotationEnabled ? .on : .off
        emojiField.stringValue = defaults.emoji
        updateCountLabel()
        updateSpeedLabel()
        updateModeControls()
    }

    private func updateCountLabel() { countValueLabel.stringValue = "Objects: \(Int(countSlider.doubleValue))" }
    private func updateSpeedLabel() { speedValueLabel.stringValue = String(format: "Speed: %.1f\u{00d7}", speedSlider.doubleValue) }

    private func updateModeControls() {
        let showEmojiField = defaults.iconMode == .emoji
        guard emojiField.isHidden != !showEmojiField else { return }
        emojiField.isHidden = !showEmojiField
        refitSize()
    }

    @objc private func iconChanged() {
        guard let mode = IconMode.allCases[safe: iconPopup.indexOfSelectedItem] else { return }
        defaults.iconMode = mode
        updateModeControls()
    }

    @objc private func emojiChanged() {
        defaults.emoji = emojiField.stringValue
    }

    @objc private func countChanged() {
        defaults.objectCount = Int(countSlider.doubleValue.rounded())
        updateCountLabel()
    }

    @objc private func speedChanged() {
        defaults.speedMultiplier = speedSlider.doubleValue
        updateSpeedLabel()
    }

    @objc private func rotationChanged() {
        defaults.rotationEnabled = rotationCheckbox.state == .on
    }

    @objc private func done() {
        onDone?()
    }
}

extension SettingsPanelView: NSTextFieldDelegate {
    /// Persist the emoji as the user types/pastes it, rather than only on
    /// Return or when the field resigns first responder — clicking "Done"
    /// directly (without pressing Return first) must not lose the change.
    func controlTextDidChange(_ obj: Notification) {
        guard (obj.object as? NSTextField) === emojiField else { return }
        defaults.emoji = emojiField.stringValue
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
