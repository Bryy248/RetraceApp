//
//  RecordingToJourney.swift
//  Retrace
//
//  Created by Brian Chang on 08/09/26.
//

import Foundation
import SwiftData

// kumpulan fungsi untuk mengubah hasil rekaman menjadi RouteData/Journey
enum RecordingToJourney {
    
    // Ambil RecordedLocation dari database, hanya syang timestamp-nya di rentang tanggal yang dipilih
    static func fetchSamples(in context: ModelContext, from start: Date, to end: Date) -> [RecordedLocation] {
        let calendar = Calendar.current
        
        let startOfDay = calendar.startOfDay(for: start) // untuk ambil dari jam 00.00.00 di tanggal start
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))! // ambil awal hari berikutnya, lalu semua yang sebelum itu, contoh sampai 8 sep, nanti diambil sebelum tanggal 9 pukul 00.00
        let descriptor = FetchDescriptor<RecordedLocation>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter {$0.timestamp >= startOfDay && $0.timestamp <= startOfNextDay}
    }
    
    // Ubah dafatr RecordedLocation -> RouteData (points terisi, visit kosong)
    static func makeRouteData(from samples: [RecordedLocation]) -> RouteData {
        let points = samples.map {RoutePoint(lat: $0.latitude, lng: $0.longitude)}
        return RouteData(points: points, visits: [])
    }
    
    static func recordedDates(in context: ModelContext) -> Set<DateComponents> {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<RecordedLocation>()
        let all = (try? context.fetch(descriptor)) ?? []
        
        let components = all.map {
            sample in calendar.dateComponents([.year, .month, .day], from: sample.timestamp)
        }
        
        return Set(components)
    }
}
