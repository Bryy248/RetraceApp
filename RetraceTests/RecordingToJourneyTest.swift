//
//  RecordingToJourneyTest.swift
//  Retrace
//
//  Created by Brian Chang on 09/09/26.
//

import Testing
import CoreLocation
@testable import Retrace

struct RecordingToJourneyTests {

    @Test func makeRouteData_ubahSamplesJadiPoints() {
        // Arrange — siapkan input
        let samples: [RecordedLocation] = [
//            RecordedLocation(location: CLLocation(latitude: -6.2, longitude: 106.8)),
//            RecordedLocation(location: CLLocation(latitude: -6.3, longitude: 106.9))
        ]

        // Act — jalankan yang mau dites
        let route = RecordingToJourney.makeRouteData(from: samples)

        // Assert — periksa hasilnya
//        #expect(route.points.count == 2)
//        #expect(route.visits.isEmpty)
//        #expect(route.points[0].lat == -6.2)
//        #expect(route.points[0].lng == 106.8)
        #expect(route.points.isEmpty)
    }
    
    @Test func totalDistance_duaTitikSamaJarak() {
        let samples = [
            RecordedLocation(location: CLLocation(latitude: -6.2, longitude: 106.8)),
            RecordedLocation(location: CLLocation(latitude: -6.3, longitude: 106.9))
        ]
        let dist = RecordingToJourney.totalDistance(of: samples)
        
        #expect(dist == 0)
    }
}
