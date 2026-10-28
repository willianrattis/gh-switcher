// Junta PNGs em um GIF animado. Uso: swift scripts/make-gif.swift <pasta-de-frames> <saida.gif> [delay]
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let delay = args.count > 3 ? Double(args[3])! : 0.1

let frames = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("Não foi possível criar \(out.path)")
}
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
for url in frames {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    CGImageDestinationAddImage(dest, image, frameProps)
}
print(CGImageDestinationFinalize(dest) ? "GIF gerado: \(out.path) (\(frames.count) frames)" : "Falhou")
