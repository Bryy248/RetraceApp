//
//  RecordingToJourney.swift
//  Retrace
//
//  Created by Brian Chang on 08/09/26.
//

import Foundation
import SwiftData
import CoreLocation

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
        return all.filter {$0.timestamp >= startOfDay && $0.timestamp < startOfNextDay}
    }
    
    // Ubah dafatr RecordedLocation -> RouteData (points terisi, visit kosong)
    static func makeRouteData(from samples: [RecordedLocation]) -> RouteData {
        let points = samples.map {RoutePoint(lat: $0.latitude, lng: $0.longitude)}
        return RouteData(points: points, visits: [])
    }
    
    // mengahsilkan tanggal tanggal yang ada datanya dalam bentuk Set
    static func recordedDates(in context: ModelContext) -> Set<DateComponents> {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<RecordedLocation>()
        let all = (try? context.fetch(descriptor)) ?? []
        
        let components = all.map {
            sample in calendar.dateComponents([.year, .month, .day], from: sample.timestamp)
        }
        
        return Set(components)
    }
    
    // hapus sample
    static func deleteSamples(on date: Date, in context: ModelContext){
        let toDelete = fetchSamples(in: context, from: date, to: date)
        for sample in toDelete {
            context.delete(sample)
        }
        try? context.save()
    }
    
    static func dailySummaries(in context: ModelContext) -> [DailyRecording] {
        let cal = Calendar.current
        let dates = recordedDates(in: context).compactMap {cal.date(from: $0)}
        
        return dates.map { date in
            let samples = fetchSamples(in: context, from: date, to: date)
            let meters = totalDistance(of: samples)
            return DailyRecording(date: date, distanceKm: meters/1000)
        }
        .sorted {$0.date > $1.date}
    }
    
    static func totalDistance(of samples: [RecordedLocation]) -> Double {
        guard samples.count > 1 else {return 0}
        var total: Double = 0
        for i in 1..<samples.count {
            let a = CLLocation(latitude: samples[i-1].latitude, longitude: samples[i-1].longitude)
            let b = CLLocation(latitude: samples[i].latitude, longitude: samples[i].longitude)
            total += b.distance(from: a)
        }
        return total
    }
}
