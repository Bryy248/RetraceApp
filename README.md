# Retrace

Aplikasi iOS yang mengubah file Timeline Google Maps menjadi video "perjalanan waktu" di peta.

## Target
- **iOS 17.0** minimum (SwiftUI Map + MapPolyline, `ContentUnavailableView`, SwiftData, `@Observable`).
- SwiftUI · SwiftData · MapKit · AVFoundation. Semua komponen HIG native, tanpa gradien.

## Struktur
- `RetraceApp.swift` — entry point, `modelContainer(for: Journey.self)`.
- `Models/Journey.swift` — model SwiftData + struct `RouteData` (Codable).
- `Parsing/CoordinateParser.swift` — membaca koordinat dari tiga encoding (`geo:`, derajat, E7).
- `Parsing/TimelineParser.swift` — mengenali tiga bentuk root: iOS (array), Android (`semanticSegments`), Takeout lama (`timelineObjects`).
- `Views/JourneyListView.swift` — daftar + empty state + tombol tambah.
- `Views/AddJourneyView.swift` — form nama, tanggal, dan `.fileImporter` untuk `Timeline.json`.
- `Views/JourneyMapView.swift` — peta dengan animasi rute, tombol putar & ekspor.
- `Export/RouteVideoExporter.swift` — snapshot peta sekali, garis tumbuh per frame, encode ke `.mp4`.

## Cara kerja singkat
Parser mengumpulkan titik dari `timelinePath` (jejak) + `visit` (tempat) dan mengurutkannya kronologis. Peta menggambar garis yang tumbuh saat diputar. Ekspor merender satu snapshot peta lalu menumpuk garis animasi + nama (atas) + periode (bawah) tiap frame, lalu menulisnya jadi video 9:16.

## Catatan format
Sejak akhir 2024 Timeline Google hanya tersimpan di perangkat; ekspornya adalah file `Timeline.json`. Parser sengaja menerima ketiga bentuk agar file dari iPhone, Android, maupun arsip Takeout lama sama-sama terbaca. Google beberapa kali mengubah format ini, jadi kalau suatu saat file baru gagal terbaca, cek kembali struktur JSON-nya terhadap `TimelineParser`.
