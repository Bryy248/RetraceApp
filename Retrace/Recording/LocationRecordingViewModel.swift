//
//  LocationRecordingViewModel.swift
//  Retrace
//
//  Created by Brian Chang on 06/09/26.
//

import Foundation
import SwiftData
import CoreLocation
import Observation

@Observable // fungsinya adalah membuat SwiftUI mengawasi class ini, sehingga apabila ada perubahan pada properti maka akan langsung refresh untuk UI nya
final class LocationRecordingViewModel {
    
    // private(set) ini artinya variabel tersebut bisa dilihat dari luar tetapi tidak bisa diubah dari luar, contohnya adalah view bisa lihat tetapi tidak bisa edit
    private(set) var samples: [RecordedLocation] = []
    private(set) var isRecording = false
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastErrorMessage: String?
    
    private let service = LocationRecordingService.shared // pakai yang sudah ada, bukan membuat objek baru
    private var context: ModelContext? // meja kerja DB, nantinya akan diisi dari view, kenapa dari view? biasanya model context itu biasanya disediakan di level view
    
    init() {
        authorizationStatus = service.authorizationStatus
        isRecording = service.getActive()
        service.onChange = { [weak self] in // untuk mengisi onChange yang ada di service
            self?.refresh()
        }
        // weak self artinya pegang viewModel secara lemah. Apa yang terjadi jika tidak weak self, maka service akan memegang kuat viewModel dan viewModel tidak akan bisa dihapus dari memori. berikut code nya jika tidak pakai weak self
//        service.onChange = {
//            self.refresh()
//        }
    }
    
    func configure(context: ModelContext) {
        guard self.context == nil else {return}
        self.context = context
        refresh()
    }
    
    private func refresh() {
        authorizationStatus = service.authorizationStatus
        isRecording = service.getActive()
        loadSamples()
    }
    
    private func loadSamples() {
        guard let context else {return}
        // membuat query
        // FetchDescriptor -> Formulir permintaan data ke SwiftData
        // <...> -> <RecordedLocation> -> Jenis yang diambil, < > artinya adalah Tipe Data nya
        // sort by itu artinya mengurutkan berdasarkan timestamp
        let descriptor = FetchDescriptor<RecordedLocation>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        // menjalankan query nya
        // context.fetch(descriptor) -> mencoba menjalankan formulir tadi
        // try? -> coba dulu, kalau gagal maka nanti hasilnya adalah [] atau array kosong
        samples = (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: Derived
    
    var sampleCount: Int {samples.count}
    // ubah tiap RecordedLocation jadi coordinatenya yang menyambung ke RecordedLocation
    // .map -> ubah tiap item jadi daftar baru tanpa menyimpan, berbeda dengan cara menggunakan for loop di mana diubah dan disimpan
    var coordinate: [CLLocationCoordinate2D] {
        samples.map(\.coordinate)
    }
    var latestSample: RecordedLocation? {samples.last}
    
    var authorizationText: String {
        switch authorizationStatus {
        case .notDetermined: return "Belum Diminta"
        case .restricted: return "Dibatasi"
        case .denied: return "Ditolak"
        case .authorizedWhenInUse: return "Saat Dipakai"
        case .authorizedAlways: return "Selalu"
        @unknown default: return "Tidak Diketahui"
        }
    }
    
    // cek izin lokasi, harus when in use atau always
    var canRecord: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // cek izin saat force quit, izin harus always saat sedang mode
    var needAlwaysForForceQuit: Bool {
        authorizationStatus != .authorizedAlways
    }
    
    func enableRecording(){
        service.enableRecording(); refresh()
    }
    
    func disableRecording(){
        service.stop(); refresh()
    }
    
    // menghitung total distance
    var totalDistance: CLLocationDistance {
        guard samples.count > 1 else {return 0}
        var total: CLLocationDistance = 0
        for i in 1..<sampleCount {
            let a = CLLocation(latitude: samples[i - 1].latitude, longitude: samples[i - 1].longitude)
            let b = CLLocation(latitude: samples[i].latitude, longitude: samples[i].longitude)
            total += b.distance(from: a)
        }
        return total
    }
    
    // MARK: Intents
    
    // request izin
    func requestAuthorization() {service.requestWhenInUse()}
    func requestAlwaysAuthorization() {service.requestAlways()}
    
    func toggleRecording() {
        service.getActive() ?service.stop() :service.start()
    }
    
    func clearSamples() {
        guard let context else {return}
        for s in samples {context.delete(s)} // untuk tiap sample hapus dari database
        try? context.save() // save ke disk
        samples.removeAll() // kosongkan juga array lokal
    }
}
