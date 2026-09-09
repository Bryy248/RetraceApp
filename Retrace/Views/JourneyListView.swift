import SwiftUI
import SwiftData

struct JourneyListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showingAdd = false
    // sementara
    @State private var showingRecordingPOC = false

    var body: some View {
        NavigationStack {
            Group {
                if journeys.isEmpty {
                    ContentUnavailableView {
                        Label("Belum ada perjalanan", systemImage: "map")
                    } description: {
                        Text("Tambahkan perjalanan pertamamu dari file Timeline Google Maps.")
                    } actions: {
                        Button("Tambah perjalanan") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(journeys) { journey in
                            NavigationLink {
                                JourneyMapView(journey: journey)
                            } label: {
                                JourneyRow(journey: journey)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Perjalanan")
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button { showingRecordingPOC = true } label: {
//                        Image(systemName: "location.magnifyingglass")
//                    }
//                }
                ToolbarItem(placement: .topBarLeading){
                    NavigationLink {
                        RecordingView()
                    } label: {
                        Image(systemName: "location")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddJourneyView()
            }
            .sheet(isPresented: $showingRecordingPOC) {
                LocationRecordingDebugView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(journeys[index]) }
    }
}

private struct JourneyRow: View {
    let journey: Journey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(journey.name)
                .font(.body)
            Text(journey.periodText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
