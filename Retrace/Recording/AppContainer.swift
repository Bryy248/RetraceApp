//
//  AppContainer.swift
//  Retrace
//
//  Created by Brian Chang on 03/09/26.
//

import SwiftData

// di sini menggunakan enum yang tidak ada case karena digunakan hanya sebagai wadah untuk namespace dan dia static. enum tanpa case tidak bisa menjadi objek, ini hanya seperti rak saja untuk menaruh static let. Opsi lainnya bisa menggunakan struct atau tanpa wadah sama sekali (langsung let shared: ... saja). Kenapa yang dipilih adalah enum, karena dengan enum langsung menutup pintu ke penggunaan yang salah. Berbeda dengan struct yang harus memberi tahu kalau jangan membuka pintu ini
// AppContainer itu semacam gudangnya swiftData
// Ada 3 lapis mental model:
// 1. Shcema: Katalog Jenis Barang yang akan disimpan contohnya di sini adalah Model
// 2. ModelConfiguration: aturan dari gudang, misalnya apakah data disimpan permanen atau hanya sementara
// 3. ModelContainer: gudang fisiknya
enum AppContainer {
    static let shared: ModelContainer = {

        let schema = Schema([Journey.self, RecordedLocation.self])
        
        // isStoredInMemoryOnly: false -> simpan permanen di disk
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        // membangun gudangnya
        do {
            return try ModelContainer(for: schema, configurations: [config])
        }
        catch {
            fatalError("Gagal membuat ModelContainer \(error)")
        }
    }()
}
