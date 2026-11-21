import AppKit
import ImageIO
import QuartzCore
import UniformTypeIdentifiers

@MainActor
final class SpriteAnimator {
    private enum Pose: String, CaseIterable {
        case sleepRest = "sleep_rest"
        case flySide = "fly_side"
        case flyDiagonal = "fly_diag_b"
        case flyVertical = "fly_vertical"
        case roarFront = "roar_front"
        case headRoar = "head_roar"

        var facesLeft: Bool { self == .flyDiagonal }
    }

    private struct Sprite {
        let image: CGImage
        let isPlaceholder: Bool
        let alpha: [UInt8]

        init(image: CGImage, isPlaceholder: Bool = false) {
            self.image = image
            self.isPlaceholder = isPlaceholder
            let width = image.width
            let height = image.height
            var rgba = [UInt8](repeating: 0, count: width * height * 4)
            rgba.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(
                    data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                        CGBitmapInfo.byteOrder32Big.rawValue
                ) else { return }

                context.draw(image, in: CGRect(x: 0, y: 0,
                                               width: CGFloat(width), height: CGFloat(height)))
            }
            alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
        }

        func containsVisiblePixel(at point: CGPoint, in bounds: CGRect) -> Bool {
            guard bounds.contains(point) else { return false }
            let x = min(image.width - 1, Int((point.x - bounds.minX) / bounds.width * CGFloat(image.width)))
            let y = min(image.height - 1, Int((bounds.maxY - point.y) / bounds.height * CGFloat(image.height)))
            return alpha[y * image.width + x] > 0
        }
    }

    private let stage = CALayer()
    private let body = CALayer()
    private let effects = CALayer()
    private let sprites: [Pose: Sprite]
    private var layers: [(layer: CALayer, sprite: Sprite)] = []

    init(in view: NSView) {
        guard let placeholder = NSImage(named: NSImage.Name("Caraxes")),
              let image = placeholder.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            preconditionFailure("The Caraxes placeholder asset is missing.")
        }
        let fallback = Sprite(image: image, isPlaceholder: true)
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CaraxesHOD/sprites", isDirectory: true)
        sprites = Dictionary(uniqueKeysWithValues: Pose.allCases.map { pose in
            let url = directory.appendingPathComponent(pose.rawValue).appendingPathExtension("png")
            let sprite = Self.loadPNG(at: url).map { Sprite(image: $0) } ?? fallback
            return (pose, sprite)
        })

        view.wantsLayer = true
        stage.frame = view.bounds
        effects.frame = stage.bounds
        body.position = CGPoint(x: stage.bounds.midX, y: 145)
        stage.addSublayer(body)
        stage.addSublayer(effects)
        view.layer?.addSublayer(stage)
    }

    private static func loadPNG(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source), type as String == UTType.png.identifier else {
            return nil
        }
        let options: [String: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways as String: true,
            kCGImageSourceThumbnailMaxPixelSize as String: 1024,
            kCGImageSourceShouldCacheImmediately as String: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    var movementBounds: CGRect {
        guard let sprite = layers.first?.layer else { return .null }
        let frame = sprite.convert(sprite.bounds, to: stage)
        return frame.union(frame.offsetBy(dx: 0, dy: 6))
    }

    func display(_ state: PetState, facingLeft: Bool = false, tilt: CGFloat = 0) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        body.removeAllAnimations()
        body.setAffineTransform(CGAffineTransform(rotationAngle: tilt))
        body.sublayers = nil
        effects.sublayers = nil
        layers.removeAll(keepingCapacity: true)

        switch state {
        case .sleep:
            let layer = addPose(.sleepRest)
            oscillate("transform.scale", from: 1, to: 1.02, duration: 2.4)
            addSleepBubbles(above: layer)
        case .idle, .perch:
            addPose(.roarFront)
            if state == .idle {
                oscillate("position.y", from: body.position.y, to: body.position.y + 6, duration: 1.3)
            }
        case .fly:
            let side = addPose(.flySide, facingLeft: facingLeft)
            let diagonal = addPose(.flyDiagonal, facingLeft: facingLeft)
            diagonal.opacity = 0
            crossfade(side, values: [1, 1, 0, 0, 1])
            crossfade(diagonal, values: [0, 0, 1, 1, 0])
        case .fire:
            let layer = addPose(.roarFront)
            addFlame(to: layer, isPlaceholder: sprites[.roarFront]?.isPlaceholder == true)
        }
    }

    func containsVisiblePixel(at point: CGPoint, usePresentation: Bool = true) -> Bool {
        guard stage.bounds.contains(point) else { return false }
        for (layer, sprite) in layers {
            if usePresentation, let rendered = layer.presentation(), let root = stage.presentation() {
                if rendered.opacity > 0.05,
                   sprite.containsVisiblePixel(at: rendered.convert(point, from: root), in: rendered.bounds) {
                    return true
                }
            } else if layer.opacity > 0.05,
                      sprite.containsVisiblePixel(at: layer.convert(point, from: stage), in: layer.bounds) {
                return true
            }
        }
        return false
    }

    @discardableResult
    private func addPose(_ pose: Pose, facingLeft: Bool? = nil) -> CALayer {
        let sprite = sprites[pose]!
        let image = sprite.image
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        let width = min(220, 230 * aspect)
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: width, height: width / aspect)
        layer.contents = image
        layer.contentsGravity = .resize
        if let facingLeft, facingLeft != (!sprite.isPlaceholder && pose.facesLeft) {
            layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        }
        body.addSublayer(layer)
        layers.append((layer, sprite))
        return layer
    }

    private func oscillate(_ keyPath: String, from: CGFloat, to: CGFloat, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        body.add(animation, forKey: keyPath)
    }

    private func crossfade(_ layer: CALayer, values: [Float]) {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = values
        fade.keyTimes = [0, 0.35, 0.5, 0.85, 1]
        fade.duration = 0.8
        fade.repeatCount = .infinity
        layer.add(fade, forKey: "flightCrossfade")
    }

    private func addSleepBubbles(above sprite: CALayer) {
        let frame = sprite.convert(sprite.bounds, to: effects)
        for index in 0..<3 {
            let bubble = CATextLayer()
            bubble.string = "Zzz"
            bubble.fontSize = 11 + CGFloat(index) * 2
            bubble.alignmentMode = .center
            bubble.foregroundColor = NSColor(calibratedRed: 0.86, green: 0.91, blue: 1, alpha: 1).cgColor
            bubble.shadowColor = NSColor.black.cgColor
            bubble.shadowOpacity = 0.8
            bubble.shadowRadius = 2
            bubble.shadowOffset = .zero
            bubble.contentsScale = 2
            bubble.bounds = CGRect(x: 0, y: 0, width: 40, height: 22)
            bubble.position = CGPoint(x: frame.midX + CGFloat(index) * 17, y: frame.maxY + 10)
            bubble.opacity = 0
            effects.addSublayer(bubble)

            let rise = CABasicAnimation(keyPath: "position.y")
            rise.fromValue = bubble.position.y
            rise.toValue = bubble.position.y + 27
            rise.duration = 3.6

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 0.95, 0.8, 0]
            fade.keyTimes = [0, 0.22, 0.62, 1]
            fade.duration = rise.duration

            let loop = CAAnimationGroup()
            loop.animations = [rise, fade]
            loop.duration = rise.duration
            loop.repeatCount = .infinity
            loop.beginTime = bubble.convertTime(CACurrentMediaTime(), from: nil) + Double(index) * 1.2
            bubble.add(loop, forKey: "sleepBubble")
        }
    }

    private func addFlame(to sprite: CALayer, isPlaceholder: Bool) {
        let mouth = isPlaceholder ? CGPoint(x: 0.86, y: 0.75) : CGPoint(x: 0.50, y: 0.58)
        let origin = CGPoint(x: sprite.bounds.width * mouth.x, y: sprite.bounds.height * mouth.y)
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = sprite.convert(origin, to: effects)
        emitter.renderMode = .additive

        let spark = CAEmitterCell()
        spark.contents = Self.flameParticle()
        spark.color = NSColor(calibratedRed: 1, green: 0.45, blue: 0.13, alpha: 0.85).cgColor
        spark.birthRate = 95
        spark.lifetime = 0.42
        spark.lifetimeRange = 0.12
        spark.velocity = 112
        spark.velocityRange = 42
        spark.emissionLongitude = isPlaceholder ? 0 : .pi / 3
        spark.emissionRange = 0.55
        spark.scale = 0.65
        spark.scaleRange = 0.28
        spark.scaleSpeed = 0.7
        spark.alphaSpeed = -1.9
        emitter.emitterCells = [spark]
        effects.addSublayer(emitter)
    }

    private static func flameParticle() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: 24, height: 24, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: [NSColor.white.cgColor, NSColor.clear.cgColor] as CFArray,
                                        locations: [0, 1]) else { return nil }
        let center = CGPoint(x: 12, y: 12)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: 12, options: [])
        return context.makeImage()
    }
}
