import SwiftUI
import MapKit

struct JourneyMapView: View {
    let journey: Journey

    @State private var revealCount = 0
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?

    // Export
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    @State private var exported: ExportedVideo?
    @State private var exportError: String?

    private var route: RouteData { journey.route }
    private var coords: [CLLocationCoordinate2D] { route.coordinates }

    var body: some View {
        VStack(spacing: 0) {
            Text(journey.name)
                .font(.headline)
                .padding(.vertical, 10)

            RoutePlaybackMap(allCoords: coords, visibleCount: revealCount)

            Text(journey.periodText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: togglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: startExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isExporting || coords.count < 2)
            }
        }
        .overlay {
            if isExporting {
                ExportingOverlay(progress: exportProgress)
            }
        }
        .onAppear { revealCount = coords.count }   // full route when idle
        .onDisappear { playTask?.cancel() }
        .sheet(item: $exported) { video in
            ActivityView(items: [video.url])
        }
        .alert("Ekspor gagal", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Playback

    private func togglePlay() {
        if isPlaying {
            playTask?.cancel()
            isPlaying = false
        } else {
            play()
        }
    }

    private func play() {
        guard coords.count >= 2 else { return }
        isPlaying = true

        let total = coords.count
        let steps = min(total, 120)                 // cap frames so each one renders
        let frameDelay: UInt64 = 60_000_000         // 60ms per step (~7s total)

        revealCount = 0
        playTask = Task {
            for step in 1...steps {
                if Task.isCancelled { break }
                let target = Int(Double(total) * Double(step) / Double(steps))
                await MainActor.run { revealCount = max(target, 2) }
                try? await Task.sleep(nanoseconds: frameDelay)
            }
            await MainActor.run {
                revealCount = total
                isPlaying = false
            }
        }
    }

    // MARK: - Export

    private func startExport() {
        isExporting = true
        exportProgress = 0

        Task {
            do {
                let exporter = RouteVideoExporter()
                let url = try await exporter.export(
                    title: journey.name,
                    periodText: journey.periodText,
                    route: route
                ) { p in exportProgress = p }

                await MainActor.run {
                    isExporting = false
                    exported = ExportedVideo(url: url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - MapKit route playback (growing polyline + orange head dot)

struct RoutePlaybackMap: UIViewRepresentable {
    let allCoords: [CLLocationCoordinate2D]
    var visibleCount: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isPitchEnabled = false

        if !allCoords.isEmpty {
            var rect = MKMapRect.null
            for c in allCoords {
                let p = MKMapPoint(c)
                rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
            }
            map.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                animated: false)
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let count = max(0, min(visibleCount, allCoords.count))
        guard count >= 2 else { return }

        let slice = Array(allCoords.prefix(count))
        map.addOverlay(MKPolyline(coordinates: slice, count: slice.count))

        if let head = slice.last {
            let dot = HeadAnnotation()
            dot.coordinate = head
            map.addAnnotation(dot)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = .systemBlue
            r.lineWidth = 5
            r.lineJoin = .round
            r.lineCap = .round
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is HeadAnnotation else { return nil }
            let id = "head"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation

            let size: CGFloat = 14
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            dot.backgroundColor = .systemOrange
            dot.layer.cornerRadius = size / 2
            dot.layer.borderWidth = 3
            dot.layer.borderColor = UIColor.white.cgColor
            dot.isUserInteractionEnabled = false

            view.frame = dot.frame
            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(dot)
            view.canShowCallout = false
            return view
        }
    }

    final class HeadAnnotation: NSObject, MKAnnotation {
        @objc dynamic var coordinate = CLLocationCoordinate2D()
    }
}

// MARK: - Supporting types

struct ExportedVideo: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ExportingOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .frame(width: 180)
                Text("Membuat video… \(Int(progress * 100))%")
                    .font(.callout)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// Native share sheet — lets the user save the video to Photos or Files.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
