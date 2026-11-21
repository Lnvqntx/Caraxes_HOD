import AppKit
import QuartzCore

@MainActor
final class SpriteAnimator {
    private let spriteLayer = CALayer()
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let pixels: [UInt8]
    private let bobHeight: CGFloat = 6
    private let bobKey = "idleBob"

    init(in view: NSView, image: CGImage, frame: CGRect) {
        pixelWidth = image.width
        pixelHeight = image.height
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                    CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                preconditionFailure("Could not allocate the Caraxes sprite bitmap.")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width),
                                           height: CGFloat(image.height)))
        }
        pixels = rgba

        view.wantsLayer = true
        spriteLayer.frame = frame
        spriteLayer.contents = image
        spriteLayer.contentsGravity = .resize
        view.layer?.addSublayer(spriteLayer)
    }

    var movementBounds: CGRect {
        spriteLayer.frame.union(spriteLayer.frame.offsetBy(dx: 0, dy: bobHeight))
    }

    func display(_ state: PetState) {
        spriteLayer.removeAnimation(forKey: bobKey)
        guard state == .idle else { return }

        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = spriteLayer.position.y
        bob.toValue = spriteLayer.position.y + bobHeight
        bob.duration = 1.3
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        spriteLayer.add(bob, forKey: bobKey)
    }

    func containsVisiblePixel(at point: CGPoint) -> Bool {
        let frame = spriteLayer.presentation()?.frame ?? spriteLayer.frame
        guard frame.contains(point) else { return false }

        let x = min(pixelWidth - 1, Int((point.x - frame.minX) / frame.width * CGFloat(pixelWidth)))
        let y = min(pixelHeight - 1, Int((frame.maxY - point.y) / frame.height * CGFloat(pixelHeight)))
        return pixels[(y * pixelWidth + x) * 4 + 3] > 0
    }
}
