import SwiftUI

/// Récords por modo (top 10) y estadísticas del jugador.
struct RecordsView: View {
    @Environment(GameModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GameMode = .freeDescent
    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Récords")
                    .font(.pixel(32))
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Picker("Modo", selection: $mode) {
                ForEach(GameMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ranking
            Divider()
            statistics

            HStack {
                Spacer()
                Button("Borrar récords y estadísticas…", role: .destructive) { confirmingReset = true }
                    .confirmationDialog(
                        "¿Borrar todos los récords y estadísticas?",
                        isPresented: $confirmingReset
                    ) {
                        Button("Borrar", role: .destructive) { model.resetRecords() }
                    } message: {
                        Text("No se puede deshacer.")
                    }
            }
        }
        .padding(24)
        .frame(width: 720, height: 620)
        .onAppear { mode = model.selectedMode }
    }

    private var ranking: some View {
        let records = model.topRecords(for: mode)
        return Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "Sin marcas en \(mode.displayName)",
                    systemImage: mode.symbolName,
                    description: Text("Termina una bajada en este modo para estrenar el ranking.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                        GridRow {
                            Text("#")
                            Text("Marca")
                            Text("Fecha")
                            Text("Detalle")
                            Text("")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        ForEach(Array(records.enumerated()), id: \.element.persistentModelID) { index, record in
                            GridRow {
                                Text("\(index + 1)")
                                    .font(.pixel(16))
                                    .foregroundStyle(index == 0 ? Theme.jacketRed : .primary)
                                Text(mode.formatRecord(record.value))
                                    .font(.pixel(16))
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                Text(record.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Button("Repetir") { model.replay(record) }
                                    .help("Volver a jugar esta montaña (semilla \(String(record.seed)))")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var statistics: some View {
        let stats = model.stats
        return VStack(alignment: .leading, spacing: 10) {
            Text("Estadísticas")
                .font(.pixel(16))
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 6) {
                GridRow {
                    StatCell(label: "Bajadas", value: "\(stats?.runs ?? 0)")
                    StatCell(label: "Metros esquiados", value: String(format: "%.0f m", stats?.totalMeters ?? 0))
                    StatCell(label: "Tiempo en la nieve", value: GameOverInfo.formatTime(stats?.totalSeconds ?? 0))
                    StatCell(label: "Caídas", value: "\(stats?.totalCrashes ?? 0)")
                }
                GridRow {
                    StatCell(label: "Atrapado por el Kunk", value: "\(stats?.kunkCaptures ?? 0)")
                    StatCell(label: "Encuentros con el Chupacabras", value: "\(stats?.chupacabrasEncounters ?? 0)")
                    StatCell(label: "Sepultado por avalanchas", value: "\(stats?.avalancheBurials ?? 0)")
                    StatCell(label: "Slaloms terminados", value: "\(stats?.slalomsFinished ?? 0)")
                }
            }
        }
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.pixel(16))
        }
        .accessibilityElement(children: .combine)
    }
}
