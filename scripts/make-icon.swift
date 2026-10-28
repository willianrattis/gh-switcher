// Gera Resources/AppIcon.icns. Uso: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// Desenha em um canvas de 1024 pontos.
func draw(_ ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Squircle no grid de ícones do macOS (824 pt, margem de 100).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    // Sombra
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x1B1E4B))
    ctx.fillPath()
    ctx.restoreGState()

    // Fundo em gradiente
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space,
                        colors: [color(0x4B4FD8), color(0x2A2D8F), color(0x12143A)] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Brilho de vidro no topo
    let gloss = CGGradient(colorsSpace: space,
                           colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(gloss, startCenter: CGPoint(x: 400, y: 900), startRadius: 0,
                           endCenter: CGPoint(x: 400, y: 900), endRadius: 620, options: [])
    ctx.restoreGState()

    // Borda de luz
    ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 3, dy: 3), cornerWidth: 183, cornerHeight: 183, transform: nil))
    ctx.setStrokeColor(color(0xFFFFFF, 0.22))
    ctx.setLineWidth(6)
    ctx.strokePath()

    let center = CGPoint(x: 512, y: 512)

    // Anel de troca: dois arcos com pontas de seta
    let ringRadius: CGFloat = 270
    ctx.setLineCap(.round)
    ctx.setLineWidth(44)
    ctx.setStrokeColor(color(0x8FD0FF))
    for start in [CGFloat.pi * 0.08, CGFloat.pi * 1.08] {
        let end = start + .pi * 0.74
        ctx.addArc(center: center, radius: ringRadius, startAngle: start, endAngle: end, clockwise: false)
        ctx.strokePath()

        // Ponta de seta no fim do arco, apontando no sentido anti-horário
        let tip = CGPoint(x: center.x + ringRadius * cos(end), y: center.y + ringRadius * sin(end))
        let tangent = CGPoint(x: -sin(end), y: cos(end))
        let normal = CGPoint(x: cos(end), y: sin(end))
        let size: CGFloat = 70
        ctx.move(to: CGPoint(x: tip.x + tangent.x * size * 0.9, y: tip.y + tangent.y * size * 0.9))
        ctx.addLine(to: CGPoint(x: tip.x + normal.x * size - tangent.x * size * 0.2,
                                y: tip.y + normal.y * size - tangent.y * size * 0.2))
        ctx.addLine(to: CGPoint(x: tip.x - normal.x * size - tangent.x * size * 0.2,
                                y: tip.y - normal.y * size - tangent.y * size * 0.2))
        ctx.closePath()
        ctx.setFillColor(color(0x8FD0FF))
        ctx.fillPath()
    }

    // Duas pessoas: uma atrás (translúcida) e uma à frente (branca)
    func person(at origin: CGPoint, scale: CGFloat, fill: CGColor) {
        let head = CGRect(x: origin.x - 62 * scale, y: origin.y + 6 * scale, width: 124 * scale, height: 124 * scale)
        ctx.addEllipse(in: head)
        let body = CGMutablePath()
        let w: CGFloat = 200 * scale
        let h: CGFloat = 150 * scale
        let base = CGRect(x: origin.x - w / 2, y: origin.y - 170 * scale, width: w, height: h)
        body.addRoundedRect(in: base, cornerWidth: w / 2.2, cornerHeight: h / 1.25)
        ctx.addPath(body)
        ctx.setFillColor(fill)
        ctx.fillPath()
    }
    person(at: CGPoint(x: 600, y: 560), scale: 0.8, fill: color(0xFFFFFF, 0.5))
    person(at: CGPoint(x: 480, y: 530), scale: 1.0, fill: color(0xFFFFFF))
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(ctx)
    try rep.representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent("\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns gerado" : "iconutil falhou")
