import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fatalError("usage: make_icon <iconset-directory>")
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: Int) -> CGImage {
    let scale = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                             bytesPerRow: size * 4, space: colorSpace,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let inset = scale * 0.025
    let corner = scale * 0.22
    let bounds = CGRect(x: inset, y: inset, width: scale - inset * 2, height: scale - inset * 2)
    let rounded = CGPath(roundedRect: bounds, cornerWidth: corner, cornerHeight: corner, transform: nil)
    context.addPath(rounded)
    context.clip()

    let gradient = CGGradient(colorsSpace: colorSpace,
                              colors: [color(0.16, 0.48, 0.98), color(0.035, 0.20, 0.68)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: scale), end: CGPoint(x: scale, y: 0), options: [])

    let lensCenter = CGPoint(x: scale * 0.43, y: scale * 0.55)
    let lensRadius = scale * 0.225
    context.setShadow(offset: CGSize(width: 0, height: -scale * 0.018), blur: scale * 0.028,
                      color: color(0, 0.06, 0.25, 0.42))
    context.setStrokeColor(color(1, 1, 1, 0.98))
    context.setLineWidth(scale * 0.09)
    context.setLineCap(.round)
    context.strokeEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                                     width: lensRadius * 2, height: lensRadius * 2))
    context.setShadow(offset: .zero, blur: 0, color: nil)

    context.setStrokeColor(color(1, 1, 1, 0.98))
    context.setLineWidth(scale * 0.105)
    context.move(to: CGPoint(x: scale * 0.59, y: scale * 0.39))
    context.addLine(to: CGPoint(x: scale * 0.79, y: scale * 0.20))
    context.strokePath()

    context.setStrokeColor(color(1, 1, 1, 0.24))
    context.setLineWidth(scale * 0.032)
    context.addArc(center: lensCenter, radius: lensRadius * 0.67, startAngle: .pi * 0.78,
                   endAngle: .pi * 1.45, clockwise: false)
    context.strokePath()
    return context.makeImage()!
}

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] {
        let pixelSize = size * scale
        let image = drawIcon(size: pixelSize)
        let url = outputDirectory.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("cannot create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(url.path)") }
    }
}
