//
//  LocationRecordingService.swift
//  Retrace
//
//  Created by Brian Chang on 03/09/26.
//

import Foundation
import SwiftData
import CoreLocation

// apa efeknya dengan ada NSObject, ini menandakan class ini mewarisi dari NSObject (class dasar warisan Objective - C). Kenapa? Karena untuk jadi "delegate" GPS, iOS mensyaratkan class-nya turunan NSObject
final class LocationRecordingService: NSObject {
    
    // ini satu satunya instance untuk seluruh app
    // static artinya dia milik class nya bukan objek, jadi ga perlu membuat objek lagi
    
    static let shared = LocationRecordingService()
    
    // variabel kosong yang diisi ViewModel, dipanggil tiap ada perubahan, agar UI Refresh
    var onChange: (() -> Void)?
    
    // mesin GPS bawaan iOS
    private let manager = CLLocationManager() // CLLocationManager -> Object bawaan iOS yang mengurus segala hal terkait lokasi/GPS
    
    // meja kerja ke gudang SwiftData yang sudah dibuat di AppContainer. Lewat ini kita bisa insert dan save data ke SwiftData
    private lazy var context = ModelContext(AppContainer.shared)
    
    // buku catatan apakah app user sedang merekam atau tidak, kenapa tidak properti biasa saja, karena ketika app ditutup properti akan hilang, jadi value nya hilang
    private let activeKey = "recording.isActive"
    
    // _ sebelum value bermakna saat kamu memanggil fungsinya tidak perlu menyebutkan nama parameternya, jadi cukup setActive(true)
    // User Default -> lemari arsip permanen di HP
    func setActive(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: activeKey)
    }
    
    func getActive() -> Bool {
        UserDefaults.standard.bool(forKey: activeKey)
    }
    // init -> konstruktor, kode yang jalan saat objek dilahirkan
    // override -> menimpa / mengganti. Kenapa perlu override, karena LocationRecorder mewarisi NSObject dan NSObject sudah memiliki init sendiri. Sehingga kalau bikin init sendiri perlu override
    override init() {
        // super.init -> jalankan dulu milik induk yaitu NSObject baru punya saya
        super.init()
        manager.delegate = self // nanti ketika mendapatkan koordinat GPS harus dilapor ke siapa, yaitu ke self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // ini adalah seberapa akurat yang diinginkan, di sini menggunakan ~10m
        manager.distanceFilter = 20 // jarak minimum sebelum lapor lagi, yaitu 20m, hemat baterai dan tidak membanjiri penyimpanan
        manager.pausesLocationUpdatesAutomatically = true // izinkan pause otomatis saat sedang diam
        manager.activityType = .otherNavigation // jenis aktivitas
    }
    
    // penanda user sedang ingin mengaktifkan izin Always
    private var pursuingAlways = false
    
    // dipanggil saat user menggeser toggle ON
    func enableRecording() {
        pursuingAlways = true
        switch authorizationStatus {
        case .notDetermined:
            requestWhenInUse() // belum ada izin -> request izin when in use
        case .authorizedWhenInUse:
            requestAlways() // kalau when in use -> request always
        case .authorizedAlways:
            start() // kalau udah always start
        default:
            pursuingAlways = false
        }
    }

    
    // untuk melihat status perizinan dari user saat ini
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    // untuk request when in use
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }
    
    // untuk request always
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }
  
    // ini bukan code yang tidak jadi digunakan, melainkan ini adalah catatan
    // manager.startUpdatingLocation() // mulai rekam lokasi user (rekam detail setiap 20m saat app hidup)
    // manager.startMonitoringSignificantLocationChanges() // ini meminta iOS untuk memantau lokasi user setiap ada perpindahan lokasi
    
    // ketika user klik start / on record location (case saat aplikasi nyala)
    // nanti flow nya adalah ketika start dipanggil nanti akan menyimpan di userdefault kalau active nya true, kemudian cek apakah ada izin sama sekali atau ga, kalau gada maka minta izin ulang, kalau sudah ada izin maka akan ke beginUpdate. beginUpdate itu isinya dicek lagi apakah izinnya always atau ga, kalau iya nanti dia bakalan nyalain auto monitoringnya dari iOS, kalau engga maka cuman ketika lagi berjalan saja app nya baru track
    func start() {
        setActive(true) // set active agar tersimpan nanti di app
        
        // cek izin terlebih dahulu
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestWhenInUse()
            onChange?()
            return
        }
        beginUpdates()
        onChange?() // untuk refresh UI
    }
    
    // ketika user klik stop / off record location
    func stop() {
        setActive(false)
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        onChange?()
    }
    
    // ini yang akan dicek apakah active monitoring nya nyala atau ga, saat app baru dibuka.
    func resumeIfNeeded() {
        // guard dipakai untuk cek syarat di awal, bisa juga pakai if tapi if itu biasanya lebih ke beberapa opsi. Untuk beda secara CPU tidak ada bedanya
        guard getActive() else {return}
        // cek apakah statusnya masih ada atau ga
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {return}
        beginUpdates()
    }
    
    private func beginUpdates() {
        if authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                manager.startMonitoringSignificantLocationChanges()
            }
        }
        manager.startUpdatingLocation()
    }
}

// extension -> menambah kemampuan baru ke sesuatu yang sudah ada
// kalau di sini extension lebih ke arah untuk memenuhi sebuah protocol yaitu adalah CLLocationManagerDelegate. Apa maksudnya, jika kamu ingin menjadi penerima laporan dari CLLocationManager maka kamu harus menyediakan method untuk menerima koordinat, dll. yang ada pada bagian manager.delegate = self
// isinya nanti ada 2 "cara aku menerima koordinat baru" dan "cara aku menerima perubahan izin"
extension LocationRecordingService: CLLocationManagerDelegate {
    
    // fungsinya memberi tahu kalau GPS sudah memperbarui lokasi dan ini lokasinya, GPS mana yang memberi update dan daftar koordinat
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // membuang lokasi yang tidak perlu apabila akurasinya negatif, jadi yang diambil hanya yang positif
        let valid = locations.filter {$0.horizontalAccuracy >= 0}
        
        // mengubah tiap CLLocation -> RecordedLocation dan menyimpannya di database
        for loc in valid {
            context.insert(RecordedLocation(location: loc))
        }
        
        // simpan permanen ke disk
        // try kalau ada ? nya artinya, coba dulu kalau gagal yasudah
        try? context.save()
        
        onChange?()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if pursuingAlways {
            switch authorizationStatus {
            case .authorizedWhenInUse:
                requestAlways() // baru dapat when in use, request always
            case .authorizedAlways:
                pursuingAlways = false // sudah alway, pengejaran selesai
                start()
            case .denied, .restricted:
                pursuingAlways = false // ditolak -> berhenti mengejar
            default:
                break
            }
        }
        onChange?()
    }
    
    // dipanggil ketika iOS gagal/error. Sengaja dikosongkan agar tidak mengganggu
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) { }
}
