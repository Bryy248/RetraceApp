//
//  RecorderLocation.swift
//  Retrace
//
//  Created by Brian Chang on 03/09/26.
//

import Foundation
import SwiftData
import CoreLocation

@Model
// final class itu artinya dia tidak bisa diturunkan / diwariskan berbeda dengan class biasa
final class RecordedLocation {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var timestamp: Date
    
    // menyimpan latitude dan longitude ke dalam coordinate yang formatnya CLLocationCoordinate2D untuk nanti menampilkan titiknya di aplikasi
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // ini akan membongkar informasi dari GPS yang dikirimkan dari iOS untuk disimpan
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
    }
}
