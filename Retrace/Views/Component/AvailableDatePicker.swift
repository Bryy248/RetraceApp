//
//  AvailableDatePicker.swift
//  Retrace
//
//  Created by Brian Chang on 08/09/26.
//

import SwiftUI
import UIKit

struct AvailableDatePicker: UIViewRepresentable {

    let canSelect: (DateComponents) -> Bool     // aturan boleh-pilih (dititipkan pemanggil)
    let decorationDates: Set<DateComponents>    // tanggal yang dikasih titik (bisa kosong)
    @Binding var selection: Date?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current
        view.delegate = context.coordinator
        let sel = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = sel
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) { }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        let parent: AvailableDatePicker
        init(_ parent: AvailableDatePicker) { self.parent = parent }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                            canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dc = normalized(dateComponents) else { return false }
            return parent.canSelect(dc)               // pakai aturan yang dititipkan
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                            didSelectDate dateComponents: DateComponents?) {
            parent.selection = dateComponents?.date
        }

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let dc = normalized(dateComponents) else { return nil }
            return parent.decorationDates.contains(dc)
                ? .default(color: .systemGreen, size: .small) : nil
        }

        private func normalized(_ dc: DateComponents?) -> DateComponents? {
            guard let dc, let date = dc.date else { return nil }
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        }
    }
}
