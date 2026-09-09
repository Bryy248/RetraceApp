//
//  RecordingView.swift
//  Retrace
//
//  Created by Brian Chang on 09/09/26.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = LocationRecordingViewModel()
    @State private var summaries: [DailyRecording] = []
    
    private func loadDates() {
        summaries = RecordingToJourney.dailySummaries(in: context)
    }
    
    private func deleteDates(at offsets: IndexSet){
        for index in offsets{
            RecordingToJourney.deleteSamples(on: summaries[index].date, in: context)
        }
        loadDates()
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Rekam lokasi", isOn: Binding(get: {viewModel.isRecording}, set: { on in
                    if on {viewModel.enableRecording()}
                    else {viewModel.disableRecording()}
                }))
            } header: {
                Text("Perekaman")
            } footer: {
                Text("Status izin: \(viewModel.authorizationText)")
            }
            
            Section {
                if summaries.isEmpty {
                    Text("Belum ada rekaman tersimpan")
                        .foregroundStyle(.secondary)
                }
                else {
                    ForEach(summaries) { item in
                        HStack {
                            Text(item.date, format: .dateTime.day().month().year())
                            Spacer()
                            Text(String(format: "%.1f km", item.distanceKm))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteDates)
                }
            } header: {
                Text("Data Rekaman")
            } footer: {
                if !summaries.isEmpty {
                    Text("Geser baris ke kiri untuk menghapus rekaman pada tanggal itu")
                }
            }
        }
        .navigationTitle("Pengatciburan Perekaman")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(context: context)
            loadDates()
        }
        .onChange(of: viewModel.sampleCount) { _, _ in
            loadDates()
        }
    }
}

#Preview {
    RecordingView()
}
