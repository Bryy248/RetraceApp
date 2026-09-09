//
//  LocationRecordingDebugView.swift
//  Retrace
//
//  Created by Brian Chang on 06/09/26.
//

import SwiftUI
import MapKit

struct LocationRecordingDebugView: View {
    @Environment(\.modelContext) private var modelContext // ambil context dari environment
    @State private var viewModel = LocationRecordingViewModel()
    @State private var camera: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            VStack {
                map
                Divider()
                resultsPanel
            }
            .navigationTitle("Rekam Aplikasi")
            .navigationBarTitleDisplayMode(.inline)
            .task {viewModel.configure(context: modelContext)}
        }
        
    }
    
    private var map: some View {
        Map(position: $camera) {
            if viewModel.coordinate.count >= 2 {
                MapPolyline(coordinates: viewModel.coordinate).stroke(.blue, lineWidth: 4)
            }
            if let last = viewModel.latestSample {
                Marker("Sekarang", coordinate: last.coordinate)
                    .tint(.orange)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: viewModel.sampleCount, { _, _ in
            guard let last = viewModel.latestSample else { return }
            withAnimation {
                camera = .region(MKCoordinateRegion(
                    center: last.coordinate,
                    latitudinalMeters: 600,
                    longitudinalMeters: 600
                ))
            }
        })
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorizationRow

            // peringatan muncul HANYA kalau izin belum "Selalu" (pakai property ViewModel-mu)
            if viewModel.needAlwaysForForceQuit {
                Label("Untuk tetap merekam setelah app ditutup paksa, izin harus \"Selalu\".",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            statsRow

            // pesan error muncul HANYA kalau ada (if let membuka opsional lastErrorMessage)
            if let msg = viewModel.lastErrorMessage {
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            controls

            // indikator "sedang merekam" muncul HANYA saat isRecording true
            if viewModel.isRecording {
                Label("Sedang merekam…", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            sampleList
        }
        .padding()
        .background(.bar)   // latar semi-transparan khas panel iOS
    }

    private var authorizationRow: some View {
        HStack {
            // authorizationText = teks hasil switch di ViewModel
            Label("Izin: \(viewModel.authorizationText)", systemImage: "location.circle")
                .font(.subheadline)
            Spacer()
            // tombol berganti sesuai status izin
            switch viewModel.authorizationStatus {
            case .notDetermined:
                Button("Minta izin") { viewModel.requestAuthorization() }
                    .font(.caption)
            case .authorizedWhenInUse:
                Button("Minta 'Selalu'") { viewModel.requestAlwaysAuthorization() }
                    .font(.caption)
            default:
                EmptyView()   // status lain: tidak ada tombol
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            stat(label: "Titik", value: "\(viewModel.sampleCount)")
            stat(label: "Jarak", value: distanceText)
            stat(label: "Akurasi", value: accuracyText)
        }
    }

    private var controls: some View {
        HStack {
            // tombol toggle: label & warna berganti sesuai isRecording
            Button(action: viewModel.toggleRecording) {
                Label(viewModel.isRecording ? "Stop" : "Mulai rekam",
                      systemImage: viewModel.isRecording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .accentColor)

            // tombol hapus: nonaktif kalau belum ada data
            Button(role: .destructive) {
                viewModel.clearSamples()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.samples.isEmpty)
        }
    }

    private var sampleList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                // reversed() → terbaru di atas; id pakai persistentModelID (gratis dari @Model)
                ForEach(viewModel.samples.reversed(), id: \.persistentModelID) { sample in
                    HStack {
                        Text(Self.timeFormatter.string(from: sample.timestamp))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.5f, %.5f", sample.latitude, sample.longitude))
                            .font(.caption.monospacedDigit())
                        Spacer()
                        Text(String(format: "±%.0fm", sample.horizontalAccuracy))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    // MARK: - Helper kecil

    // fungsi yang mengembalikan View — dipakai berulang di statsRow (3 kolom seragam)
    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }

    // format jarak: km kalau >= 1000m, else meter (mengacu ke totalDistance ViewModel)
    private var distanceText: String {
        let meters = viewModel.totalDistance
        return meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    // format akurasi titik terbaru; "–" kalau tidak ada / tidak valid
    private var accuracyText: String {
        guard let acc = viewModel.latestSample?.horizontalAccuracy, acc >= 0 else { return "–" }
        return String(format: "±%.0f m", acc)
    }

    // formatter jam:menit:detik — static let + closure {}() (pola dari AppContainer!)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

#Preview {
    LocationRecordingDebugView()
}
