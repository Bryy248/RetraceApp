import Foundation
import MapKit
import AVFoundation
import UIKit

enum ExportError: LocalizedError {
    case notEnoughPoints
    case snapshotFailed
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .notEnoughPoints: return "Rute terlalu pendek untuk dijadikan video."
        case .snapshotFailed:  return "Gagal merender peta."
        case .writerFailed(let m): return "Gagal menulis video: \(m)"
        }
    }
}

/// Renders a "time-travel" video: the map is snapshotted once, then a growing
/// polyline is drawn on top frame-by-frame and encoded to an .mp4.
///
/// MapKit can't be screen-recorded cleanly, so this is the reliable path:
/// `MKMapSnapshotter` for the map tiles, Core Graphics for the animated line and
/// text, `AVAssetWriter` for the file.
struct RouteVideoExporter {

    var size = CGSize(width: 1080, height: 1920)   // 9:16
    var fps: Int32 = 30
    var duration: Double = 8.0                     // seconds
    var lineColor = UIColor.systemBlue

    /// - Parameter progress: 0...1, reported on the main actor during encoding.
    func export(title: String,
                periodText: String,
                route: RouteData,
                progress: @escaping (Double) -> Void) async throws -> URL {

        let coords = route.coordinates
        guard coords.count >= 2 else { throw ExportError.notEnoughPoints }

        // 1. Snapshot the base map once, fitting the whole route.
        let base = try await snapshot(for: coords)
        let points = coords.map { base.point(for: $0) }

        // 2. Set up the writer.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Retrace-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])

        guard writer.canAdd(input) else { throw ExportError.writerFailed("input rejected") }
        writer.add(input)
        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(duration * Double(fps))

        // 3. Draw each frame: base image + line revealed up to this frame + labels.
        for frame in 0..<totalFrames {
            let t = Double(frame) / Double(max(totalFrames - 1, 1))   // 0...1
            let revealCount = max(2, Int(ceil(Double(points.count) * t)))
            let image = renderFrame(base: base.image,
                                    points: Array(points.prefix(revealCount)),
                                    title: title,
                                    periodText: periodText)

            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }

            guard let buffer = pixelBuffer(from: image) else {
                throw ExportError.writerFailed("pixel buffer")
            }
            let time = CMTime(value: Int64(frame), timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)

            let p = Double(frame + 1) / Double(totalFrames)
            await MainActor.run { progress(p) }
        }

        input.markAsFinished()
        await withCheckedContinuation { cont in
            writer.finishWriting { cont.resume() }
        }
        guard writer.status == .completed else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "finish")
        }
        return url
    }

    // MARK: - Map snapshot

    private func snapshot(for coords: [CLLocationCoordinate2D]) async throws -> MKMapSnapshotter.Snapshot {
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = 1            // 1 point == 1 pixel, so point(for:) maps to pixels
        options.region = region(for: coords)
        options.showsBuildings = true
        if #available(iOS 17.0, *) {
            options.preferredConfiguration = MKStandardMapConfiguration()
        }

        let snapshotter = MKMapSnapshotter(options: options)
        return try await withCheckedThrowingContinuation { cont in
            snapshotter.start { snap, error in
                if let snap { cont.resume(returning: snap) }
                else { cont.resume(throwing: error ?? ExportError.snapshotFailed) }
            }
        }
    }

    private func region(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLng = coords[0].longitude, maxLng = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
                                    longitudeDelta: max((maxLng - minLng) * 1.4, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Per-frame drawing

    private func renderFrame(base: UIImage,
                             points: [CGPoint],
                             title: String,
                             periodText: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            // The growing route line.
            if points.count >= 2 {
                let path = UIBezierPath()
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
                lineColor.setStroke()
                path.lineWidth = 8
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                path.stroke()

                // Head marker.
                if let head = points.last {
                    let dot = UIBezierPath(arcCenter: head, radius: 14,
                                           startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    UIColor.systemOrange.setFill()
                    dot.fill()
                    UIColor.white.setStroke()
                    dot.lineWidth = 4
                    dot.stroke()
                }
            }

            drawBanner(title, at: .top, in: ctx.cgContext)
            drawBanner(periodText, at: .bottom, in: ctx.cgContext, small: true)
        }
    }

    private enum BannerEdge { case top, bottom }

    private func drawBanner(_ text: String, at edge: BannerEdge,
                            in ctx: CGContext, small: Bool = false) {
        let bandHeight: CGFloat = small ? 120 : 160
        let rect = CGRect(x: 0,
                          y: edge == .top ? 0 : size.height - bandHeight,
                          width: size.width, height: bandHeight)

        ctx.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fill(rect)

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: small ? 40 : 60, weight: small ? .regular : .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: style
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let textSize = attributed.boundingRect(
            with: CGSize(width: size.width - 80, height: bandHeight),
            options: .usesLineFragmentOrigin, context: nil).size
        let textRect = CGRect(x: 40,
                              y: rect.midY - textSize.height / 2,
                              width: size.width - 80, height: textSize.height)
        attributed.draw(in: textRect)
    }

    // MARK: - CVPixelBuffer

    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB, attrs, &pb)
        guard let buffer = pb, let cg = image.cgImage else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        context?.draw(cg, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
