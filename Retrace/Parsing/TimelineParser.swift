import Foundation

enum TimelineParseError: LocalizedError {
    case unreadableFile
    case unknownFormat
    case noRoute

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "File tidak bisa dibaca. Pastikan itu Timeline.json dari Google Maps."
        case .unknownFormat:  return "Format file tidak dikenali. Ekspor ulang dari Google Maps (Timeline.json)."
        case .noRoute:        return "Tidak ada rute pada rentang tanggal itu. Coba ubah tanggalnya."
        }
    }
}

/// Reads a Google Maps Timeline export into an ordered `RouteData`,
/// optionally limited to a date range.
enum TimelineParser {

    static func parse(data: Data, from: Date? = nil, to: Date? = nil) throws -> RouteData {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw TimelineParseError.unreadableFile
        }

        let interval = makeInterval(from: from, to: to)

        let route: RouteData
        switch json {
        case let array as [Any]:
            route = parseSemanticSegments(array, interval: interval)          // iOS
        case let object as [String: Any]:
            if let segments = object["semanticSegments"] as? [Any] {
                route = parseSemanticSegments(segments, interval: interval)    // Android
            } else if let objects = object["timelineObjects"] as? [Any] {
                route = parseTimelineObjects(objects, interval: interval)      // Legacy Takeout
            } else {
                throw TimelineParseError.unknownFormat
            }
        default:
            throw TimelineParseError.unknownFormat
        }

        guard !route.points.isEmpty || !route.visits.isEmpty else {
            throw TimelineParseError.noRoute
        }
        return route
    }

    static func dateRange(data: Data) -> (start: Date, end: Date)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let segments: [Any]
        if let array = json as? [Any] {
            segments = array
        } else if let obj = json as? [String: Any] {
            segments = (obj["semanticSegments"] as? [Any])
                ?? (obj["timelineObjects"] as? [Any]) ?? []
        } else { return nil }

        var dates: [Date] = []
        for case let seg as [String: Any] in segments {
            let inner = (seg["activitySegment"] as? [String: Any])
                ?? (seg["placeVisit"] as? [String: Any]) ?? seg
            if let s = isoDate(inner["startTime"]) ?? isoDate((inner["duration"] as? [String: Any])?["startTimestamp"]) {
                dates.append(s)
            }
            if let e = isoDate(inner["endTime"]) ?? isoDate((inner["duration"] as? [String: Any])?["endTimestamp"]) {
                dates.append(e)
            }
        }
        guard let min = dates.min(), let max = dates.max() else { return nil }
        return (min, max)
    }

    // MARK: - On-device (iOS + Android)

    private static func parseSemanticSegments(_ segments: [Any], interval: DateInterval?) -> RouteData {
        let sorted = segments
            .compactMap { $0 as? [String: Any] }
            .sorted { (isoDate($0["startTime"]) ?? .distantPast) < (isoDate($1["startTime"]) ?? .distantPast) }

        var points: [RoutePoint] = []
        var visits: [RouteVisit] = []

        for seg in sorted {
            // Date filter: keep only segments whose start falls in range.
            if let interval {
                guard let t = isoDate(seg["startTime"]), interval.contains(t) else { continue }
            }

            if let visit = seg["visit"] as? [String: Any],
               let top = visit["topCandidate"] as? [String: Any],
               let coord = CoordinateParser.parse(top["placeLocation"]) {
                let name = (top["semanticType"] as? String)
                    ?? (top["placeId"] as? String)
                    ?? (top["placeID"] as? String)
                visits.append(RouteVisit(lat: coord.lat, lng: coord.lng, name: name))
                points.append(coord)
            }

            if let activity = seg["activity"] as? [String: Any] {
                if let start = CoordinateParser.parse(activity["start"]) { points.append(start) }
                if let end = CoordinateParser.parse(activity["end"]) { points.append(end) }
            }

            if let path = seg["timelinePath"] as? [Any] {
                for case let node as [String: Any] in path {
                    if let p = CoordinateParser.parse(node["point"]) { points.append(p) }
                }
            }
        }
        return RouteData(points: dedupe(points), visits: visits)
    }

    // MARK: - Legacy Takeout

    private static func parseTimelineObjects(_ objects: [Any], interval: DateInterval?) -> RouteData {
        var points: [RoutePoint] = []
        var visits: [RouteVisit] = []

        for case let obj as [String: Any] in objects {
            let inner = (obj["placeVisit"] as? [String: Any])
                ?? (obj["activitySegment"] as? [String: Any]) ?? obj
            if let interval {
                let duration = inner["duration"] as? [String: Any]
                guard let t = isoDate(duration?["startTimestamp"]), interval.contains(t) else { continue }
            }

            if let visit = obj["placeVisit"] as? [String: Any],
               let location = visit["location"] as? [String: Any],
               let coord = CoordinateParser.parse(location) {
                let name = location["name"] as? String ?? location["address"] as? String
                visits.append(RouteVisit(lat: coord.lat, lng: coord.lng, name: name))
                points.append(coord)
            }

            if let activity = obj["activitySegment"] as? [String: Any] {
                if let start = activity["startLocation"] as? [String: Any],
                   let c = CoordinateParser.parse(start) { points.append(c) }

                for key in ["waypointPath", "simplifiedRawPath"] {
                    guard let path = activity[key] as? [String: Any] else { continue }
                    let nodes = (path["waypoints"] as? [Any]) ?? (path["points"] as? [Any]) ?? []
                    for case let node as [String: Any] in nodes {
                        if let c = CoordinateParser.parse(node) { points.append(c) }
                    }
                }

                if let end = activity["endLocation"] as? [String: Any],
                   let c = CoordinateParser.parse(end) { points.append(c) }
            }
        }
        return RouteData(points: dedupe(points), visits: visits)
    }

    // MARK: - Helpers

    /// Whole-day inclusive interval from the picked dates (end day fully included).
    private static func makeInterval(from: Date?, to: Date?) -> DateInterval? {
        guard from != nil || to != nil else { return nil }
        let cal = Calendar.current
        let start = from.map { cal.startOfDay(for: $0) } ?? .distantPast
        let end = to.map { cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: $0)) ?? $0 } ?? .distantFuture
        return DateInterval(start: start, end: max(start, end))
    }

    private static func dedupe(_ points: [RoutePoint]) -> [RoutePoint] {
        var out: [RoutePoint] = []
        for p in points where p != out.last { out.append(p) }
        return out
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    private static func isoDate(_ any: Any?) -> Date? {
        guard let s = any as? String else { return nil }
        return isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }
}
