import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AddJourneyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingImporter = false

    @State private var importedData: Data?
    @State private var parsedRoute: RouteData?
    @State private var importedFilename: String?
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedRoute != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nama") {
                    TextField("Liburan Jepang", text: $name)
                }

                Section("Periode") {
                    DatePicker("Mulai", selection: $startDate, displayedComponents: .date)
                    DatePicker("Selesai", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        HStack {
                            Label(importedFilename ?? "Pilih Timeline.json",
                                  systemImage: "square.and.arrow.down")
                            Spacer()
                            if parsedRoute != nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    if let route = parsedRoute {
                        Text("\(route.points.count) titik · \(route.visits.count) tempat pada rentang ini")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Data Google Maps")
                } footer: {
                    Text("Ekspor dari Google Maps: foto profil → Setelan → Lokasi & Privasi → Export Timeline data.")
                }
            }
            .navigationTitle("Perjalanan baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan", action: save).disabled(!canSave)
                }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false,
                          onCompletion: handleImport)
            .onChange(of: startDate) { _, _ in refilter() }
            .onChange(of: endDate) { _, _ in refilter() }
            .alert("Tidak bisa memuat file",
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }

        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

        do {
            importedData = try Data(contentsOf: url)
            importedFilename = url.lastPathComponent
            refilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-parse the stored file for the currently selected date range.
    private func refilter() {
        guard let data = importedData else { return }
        do {
            parsedRoute = try TimelineParser.parse(data: data, from: startDate, to: endDate)
        } catch {
            parsedRoute = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let route = parsedRoute else { return }
        let journey = Journey(name: name.trimmingCharacters(in: .whitespaces),
                              startDate: startDate,
                              endDate: endDate,
                              route: route)
        context.insert(journey)
        dismiss()
    }
}
