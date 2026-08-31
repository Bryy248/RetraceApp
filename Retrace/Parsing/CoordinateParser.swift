import Foundation

/// Parses a coordinate out of whatever shape Google happened to write it in.
///
/// Handles the three known encodings:
///   • iOS on-device:      "geo:45.4642,9.1900"  (a plain string)
///   • Android on-device:  "45.4642°, 9.1900°"   (string, degree signs) or { "latLng": "…" }
///   • Legacy Takeout:     { "latitudeE7": 454642000, "longitudeE7": 91900000 }  (E7 integers)
enum CoordinateParser {

    /// Returns nil unless BOTH halves parse to finite, in-range numbers.
    /// A half-parsed coordinate is worse than none — it lands somewhere plausible.
    static func parse(_ value: Any?) -> RoutePoint? {
        switch value {
        case let s as String:
            return parseString(s)
        case let dict as [String: Any]:
            return parseDict(dict)
        default:
            return nil
        }
    }

    // MARK: String forms ("geo:…" and "x°, y°")

    private static func parseString(_ raw: String) -> RoutePoint? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("geo:") { s.removeFirst(4) }
        s = s.replacingOccurrences(of: "°", with: "")

        let parts = s.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lng = Double(parts[1]) else { return nil }
        return validated(lat: lat, lng: lng)
    }

    // MARK: Dict forms (nested latLng, or E7 integers under various keys)

    private static func parseDict(_ dict: [String: Any]) -> RoutePoint? {
        // Android nests the string one level deeper.
        if let nested = dict["latLng"] { return parse(nested) }
        // iOS visit coordinate can arrive as { "placeLocation": "geo:…" } handled upstream.

        // Legacy E7 integers, in any of the spellings Google uses.
        let latKeys = ["latitudeE7", "centerLatE7", "latE7"]
        let lngKeys = ["longitudeE7", "centerLngE7", "lngE7"]
        if let latRaw = firstNumber(in: dict, keys: latKeys),
           let lngRaw = firstNumber(in: dict, keys: lngKeys) {
            let lat = fromE7(latRaw, ceiling: 900_000_000)
            let lng = fromE7(lngRaw, ceiling: 1_800_000_000)
            return validated(lat: lat, lng: lng)
        }
        return nil
    }

    private static func firstNumber(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let n = dict[key] as? Double { return n }
            if let n = dict[key] as? Int { return Double(n) }
            if let s = dict[key] as? String, let n = Double(s) { return n }
        }
        return nil
    }

    /// Takeout sometimes ships a negative E7 wrapped as an unsigned 32-bit int,
    /// arriving as the true value + 2^32. A wrap is always a large positive number,
    /// so anything above the axis ceiling gets 2^32 subtracted. Each axis judged alone.
    private static func fromE7(_ raw: Double, ceiling: Double) -> Double {
        var v = raw
        if v > ceiling { v -= 4_294_967_296 } // 2^32
        return v / 1e7
    }

    private static func validated(lat: Double, lng: Double) -> RoutePoint? {
        guard lat.isFinite, lng.isFinite,
              lat >= -90, lat <= 90,
              lng >= -180, lng <= 180 else { return nil }
        return RoutePoint(lat: lat, lng: lng)
    }
}
