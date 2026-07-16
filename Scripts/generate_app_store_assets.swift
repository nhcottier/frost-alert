import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = root.appendingPathComponent("App Store Assets/Screenshots")
let docsAssetsDir = root.appendingPathComponent("docs/assets")
let iconURL = root.appendingPathComponent("Frost Alert/Assets.xcassets/AppIcon.appiconset/FrostAlertIcon.png")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: docsAssetsDir, withIntermediateDirectories: true)

let iconImage = NSImage(contentsOf: iconURL)
try? FileManager.default.copyItem(at: iconURL, to: docsAssetsDir.appendingPathComponent("frost-alert-icon.png"))

struct Palette {
    static let backgroundTop = NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.00, alpha: 1)
    static let backgroundBottom = NSColor(calibratedRed: 0.76, green: 0.89, blue: 1.00, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.18, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.43, green: 0.49, blue: 0.57, alpha: 1)
    static let blue = NSColor(calibratedRed: 0.04, green: 0.33, blue: 0.70, alpha: 1)
    static let green = NSColor(calibratedRed: 0.13, green: 0.48, blue: 0.29, alpha: 1)
    static let watch = NSColor(calibratedRed: 0.63, green: 0.43, blue: 0.08, alpha: 1)
    static let frost = NSColor(calibratedRed: 0.02, green: 0.22, blue: 0.58, alpha: 1)
    static let white = NSColor.white
    static let panel = NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.0, alpha: 1)
}

func paragraph(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Palette.ink, alignment: NSTextAlignment = .left) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = size * 0.12
    return NSAttributedString(
        string: text,
        attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
            .kern: 0
        ]
    )
}

func drawText(_ text: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Palette.ink, alignment: NSTextAlignment = .left) {
    paragraph(text, size: size, weight: weight, color: color, alignment: alignment).draw(in: rect)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat = 2) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

func drawShadowedCard(_ rect: CGRect, radius: CGFloat = 32) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    fillRounded(rect, radius: radius, color: Palette.white.withAlphaComponent(0.94))
    NSGraphicsContext.restoreGraphicsState()
    strokeRounded(rect, radius: radius, color: Palette.blue.withAlphaComponent(0.12), width: 2)
}

func drawPill(_ rect: CGRect, text: String, color: NSColor, textSize: CGFloat = 34) {
    fillRounded(rect, radius: rect.height / 2, color: color.withAlphaComponent(0.12))
    drawText(text, in: rect.insetBy(dx: 28, dy: 9), size: textSize, weight: .bold, color: color, alignment: .center)
}

func drawIcon(in rect: CGRect) {
    if let iconImage {
        iconImage.draw(in: rect)
    } else {
        fillRounded(rect, radius: rect.width * 0.22, color: Palette.blue)
        drawText("*", in: rect.insetBy(dx: 20, dy: 10), size: rect.width * 0.55, weight: .bold, color: .white, alignment: .center)
    }
}

func drawBackground(_ size: CGSize) {
    let gradient = NSGradient(colors: [Palette.backgroundTop, Palette.backgroundBottom])!
    gradient.draw(in: CGRect(origin: .zero, size: size), angle: -90)

    Palette.white.withAlphaComponent(0.28).setFill()
    NSBezierPath(ovalIn: CGRect(x: -180, y: size.height - 620, width: 760, height: 760)).fill()
    NSBezierPath(ovalIn: CGRect(x: size.width - 420, y: 300, width: 620, height: 620)).fill()
}

func drawPhoneShell(_ rect: CGRect) {
    fillRounded(rect, radius: 72, color: Palette.ink)
    fillRounded(rect.insetBy(dx: 16, dy: 16), radius: 58, color: NSColor(calibratedRed: 0.91, green: 0.96, blue: 1.0, alpha: 1))
    fillRounded(CGRect(x: rect.midX - 88, y: rect.maxY - 48, width: 176, height: 18), radius: 9, color: Palette.ink.withAlphaComponent(0.20))
}

func drawDashboardMock(in rect: CGRect, risk: String, riskColor: NSColor, location: String, low: String, frost: String) {
    drawPhoneShell(rect)
    let content = rect.insetBy(dx: 58, dy: 78)
    drawIcon(in: CGRect(x: content.midX - 44, y: content.maxY - 92, width: 58, height: 58))
    drawText("Frost Alert", in: CGRect(x: content.midX + 26, y: content.maxY - 80, width: 260, height: 48), size: 31, weight: .bold)
    drawText("Tonight and tomorrow morning", in: CGRect(x: content.minX, y: content.maxY - 205, width: content.width, height: 46), size: 28, weight: .semibold, color: Palette.muted)
    drawText(risk, in: CGRect(x: content.minX, y: content.maxY - 330, width: content.width, height: 110), size: risk.count > 10 ? 48 : 68, weight: .bold, color: riskColor)
    drawText("Focused frost guidance for growing locations.", in: CGRect(x: content.minX, y: content.maxY - 415, width: content.width, height: 80), size: 27, color: Palette.muted)

    let card = CGRect(x: content.minX, y: content.maxY - 720, width: content.width, height: 230)
    drawShadowedCard(card, radius: 24)
    drawText(location, in: CGRect(x: card.minX + 36, y: card.maxY - 82, width: 390, height: 52), size: 36, weight: .bold)
    drawText("Grapes - Sensitive", in: CGRect(x: card.minX + 36, y: card.maxY - 132, width: 390, height: 44), size: 27, color: Palette.muted)
    drawText("Low \(low) | Frost: \(frost)", in: CGRect(x: card.minX + 36, y: card.maxY - 178, width: 480, height: 42), size: 25, color: Palette.muted)
    drawPill(CGRect(x: card.maxX - 210, y: card.maxY - 95, width: 166, height: 62), text: risk == "Severe frost risk" ? "Severe" : risk, color: riskColor, textSize: 28)
}

func drawOutlookCard(in rect: CGRect) {
    drawShadowedCard(rect, radius: 24)
    drawText("3-day frost outlook", in: CGRect(x: rect.minX + 34, y: rect.maxY - 68, width: rect.width - 68, height: 42), size: 28, weight: .bold, color: Palette.muted)
    let rows = [
        ("Tonight", "-0.8 C low", "Watch", Palette.watch),
        ("Tomorrow night", "-1.4 C low", "Frost likely", Palette.frost),
        ("Sunday night", "-2.1 C low", "Severe", Palette.frost)
    ]
    for (index, row) in rows.enumerated() {
        let y = rect.maxY - 145 - CGFloat(index * 105)
        drawText(row.0, in: CGRect(x: rect.minX + 34, y: y, width: 360, height: 42), size: 31, weight: .bold)
        drawText(row.1, in: CGRect(x: rect.minX + 34, y: y - 42, width: 260, height: 34), size: 23, color: Palette.muted)
        drawPill(CGRect(x: rect.maxX - 240, y: y - 10, width: 194, height: 58), text: row.2, color: row.3, textSize: row.2.count > 7 ? 22 : 27)
    }
}

func drawAlertCard(in rect: CGRect) {
    drawShadowedCard(rect, radius: 28)
    drawIcon(in: CGRect(x: rect.minX + 34, y: rect.maxY - 104, width: 70, height: 70))
    drawText("Queenstown: frost risk", in: CGRect(x: rect.minX + 128, y: rect.maxY - 88, width: rect.width - 170, height: 44), size: 30, weight: .bold)
    drawText("Check protection before sunrise. Forecast low: -1.4 C.", in: CGRect(x: rect.minX + 128, y: rect.maxY - 152, width: rect.width - 170, height: 82), size: 28, color: Palette.ink)
}

func drawFeatureList(in rect: CGRect) {
    let items = [
        "Cover sensitive plants",
        "Move pots inside",
        "Check frost cloth and irrigation",
        "Protect seedlings before evening"
    ]
    drawShadowedCard(rect, radius: 28)
    drawText("Practical actions", in: CGRect(x: rect.minX + 34, y: rect.maxY - 72, width: rect.width - 68, height: 44), size: 32, weight: .bold)
    for (index, item) in items.enumerated() {
        let y = rect.maxY - 145 - CGFloat(index * 64)
        Palette.green.setStroke()
        let circle = NSBezierPath(ovalIn: CGRect(x: rect.minX + 38, y: y + 6, width: 28, height: 28))
        circle.lineWidth = 4
        circle.stroke()
        drawText(item, in: CGRect(x: rect.minX + 84, y: y, width: rect.width - 120, height: 44), size: 27, color: Palette.ink)
    }
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FrostAssetGenerator", code: 1)
    }
    try png.write(to: url)
}

func render(name: String, headline: String, subhead: String, draw: (CGSize) -> Void) throws {
    let size = CGSize(width: 1242, height: 2688)
    let image = NSImage(size: size)
    image.lockFocus()
    drawBackground(size)
    drawIcon(in: CGRect(x: 92, y: size.height - 214, width: 92, height: 92))
    drawText("Frost Alert", in: CGRect(x: 208, y: size.height - 192, width: 520, height: 64), size: 42, weight: .bold)
    drawText(headline, in: CGRect(x: 92, y: size.height - 430, width: size.width - 184, height: 150), size: 68, weight: .bold)
    drawText(subhead, in: CGRect(x: 92, y: size.height - 575, width: size.width - 184, height: 110), size: 34, color: Palette.muted)
    draw(size)
    image.unlockFocus()
    try writePNG(image, to: outputDir.appendingPathComponent(name))
}

func resizeForAppStore(_ filename: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "2688", "1242", outputDir.appendingPathComponent(filename).path]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
}

try render(
    name: "01-frost-risk-dashboard.png",
    headline: "Know tonight's frost risk at a glance",
    subhead: "Clear guidance for gardens, orchards, vineyards, nurseries, and lifestyle blocks."
) { size in
    drawDashboardMock(in: CGRect(x: 250, y: 250, width: 790, height: 1720), risk: "Safe", riskColor: Palette.green, location: "Home", low: "8.4 C", frost: "None")
}

try render(
    name: "02-three-day-outlook.png",
    headline: "Plan protection up to three nights ahead",
    subhead: "See the nights that need attention before frost-sensitive plants are exposed."
) { size in
    drawDashboardMock(in: CGRect(x: 112, y: 230, width: 620, height: 1510), risk: "Watch", riskColor: Palette.watch, location: "Vineyard", low: "-0.8 C", frost: "None")
    drawOutlookCard(in: CGRect(x: 635, y: 540, width: 555, height: 430))
}

try render(
    name: "03-frost-alerts.png",
    headline: "Evening and morning alerts",
    subhead: "Local notifications warn when the latest forecast shows frost risk."
) { size in
    drawAlertCard(in: CGRect(x: 130, y: 1210, width: 1030, height: 240))
    drawAlertCard(in: CGRect(x: 130, y: 900, width: 1030, height: 240))
    drawDashboardMock(in: CGRect(x: 320, y: 130, width: 650, height: 720), risk: "Frost likely", riskColor: Palette.frost, location: "Orchard", low: "-1.4 C", frost: "2:00 AM")
}

try render(
    name: "04-practical-actions.png",
    headline: "Simple actions, not a weather dashboard",
    subhead: "Frost Alert focuses on what matters: risk, timing, crop sensitivity, and next steps."
) { size in
    drawDashboardMock(in: CGRect(x: 100, y: 250, width: 610, height: 1430), risk: "Watch", riskColor: Palette.watch, location: "Seedlings", low: "1.2 C", frost: "None")
    drawFeatureList(in: CGRect(x: 645, y: 600, width: 545, height: 410))
}

[
    "01-frost-risk-dashboard.png",
    "02-three-day-outlook.png",
    "03-frost-alerts.png",
    "04-practical-actions.png"
].forEach(resizeForAppStore)

print("Generated App Store screenshots in \(outputDir.path)")
