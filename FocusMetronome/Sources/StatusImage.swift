import AppKit

/// Иконка и темп в строке меню одним шаблонным изображением.
///
/// Шаблон (template) красится строкой меню сама — светлая/тёмная тема, выделение.
/// Для шаблонов важен только альфа-канал, поэтому тусклые цифры на паузе —
/// это просто полупрозрачная заливка.
enum StatusImage {
    static func make(bpm: Int?, active: Bool, dimmed: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let symbolName = active ? "metronome.fill" : "metronome"
        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Metronome")?
            .withSymbolConfiguration(config) ?? NSImage()

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let text = bpm.map { String($0) }
        // Ширина всегда под три цифры: соседние иконки не дёргаются при смене темпа.
        let textWidth = text == nil ? 0 : ceil(("000" as NSString).size(withAttributes: [.font: font]).width)
        let gap: CGFloat = text == nil ? 0 : 4
        let height: CGFloat = 18
        let size = NSSize(width: ceil(icon.size.width) + gap + textWidth, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            let iconRect = NSRect(
                x: 0,
                y: (height - icon.size.height) / 2,
                width: icon.size.width,
                height: icon.size.height
            )
            icon.draw(in: iconRect)
            if let text {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.black.withAlphaComponent(dimmed ? 0.4 : 1),
                ]
                let textSize = (text as NSString).size(withAttributes: attributes)
                let origin = NSPoint(x: ceil(icon.size.width) + gap, y: (height - textSize.height) / 2)
                (text as NSString).draw(at: origin, withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = text.map { "Metronome \($0) BPM" } ?? "Metronome"
        return image
    }
}
