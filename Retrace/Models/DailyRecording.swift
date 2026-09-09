//
//  DailyRecording.swift
//  Retrace
//
//  Created by Brian Chang on 09/09/26.
//

import Foundation

struct DailyRecording: Identifiable {
    let id = UUID()
    let date: Date
    let distanceKm: Double
}
