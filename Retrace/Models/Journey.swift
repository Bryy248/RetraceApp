import Foundation
import SwiftData
import CoreLocation

// MARK: - Stored route payload

/// A single ordered point on the drawn line.
struct RoutePoint: Codable, Hashable {
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// A place the user actually visited (shown as a marker).
struct RouteVisit: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var lat: Double
    var lng: Double
    var name: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// The whole parsed timeline: an ordered line plus visited places.
struct RouteData: Codable {
    var points: [RoutePoint]
    var visits: [RouteVisit]

    static let empty = RouteData(points: [], visits: [])

    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }
}

// MARK: - Persisted journey

@Model
final class Journey {
    var name: String
    var startDate: Date
    var endDate: Date
    /// JSON-encoded `RouteData`. Stored as Data so SwiftData keeps it opaque.
    var routeData: Data
    var createdAt: Date

    init(name: String, startDate: Date, endDate: Date, route: RouteData) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.routeData = (try? JSONEncoder().encode(route)) ?? Data()
        self.createdAt = Date()
    }

    var route: RouteData {
        (try? JSONDecoder().decode(RouteData.self, from: routeData)) ?? .empty
    }

    /// "1 – 14 Apr 2026" style label for the header/footer.
    var periodText: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        let start = f.string(from: startDate)
        let end = f.string(from: endDate)
        return start == end ? start : "\(start) – \(end)"
    }
}
