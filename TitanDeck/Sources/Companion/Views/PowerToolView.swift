// Companion/Views/PowerToolView.swift
import SwiftUI

/// Power budget against a distro, plus cable sizing with temperature derating.
struct PowerToolView: View {
    let library: FixtureLibrary
    @AppStorage(CompanionSettings.voltageKey) private var voltage: Double = 230
    @State private var items: [PowerBudget.Item] = []
    @State private var distroAmps: Double = 32
    @State private var ambient: Double = 30
    @State private var addingFixtureID: String?
    @State private var showingPicker = false

    private static let distroRatings: [Double] = [13, 16, 32, 63, 125]

    init(library: FixtureLibrary, initialFixtureID: String? = nil) {
        self.library = library
        if let id = initialFixtureID, let fixture = library.fixture(id: id), let watts = fixture.powerW {
            _items = State(initialValue: [PowerBudget.Item(name: fixture.model, watts: watts, quantity: 1)])
        }
    }

    private var result: PowerBudget.Result {
        PowerBudget.compute(items: items, voltage: voltage, distroRatingAmps: distroAmps)
    }

    var body: some View {
        Form {
            Section {
                loadGauge
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: $item.name)
                            .font(.body.weight(.medium))
                        HStack {
                            TextField("Watts", value: $item.watts, format: .number)
                                .keyboardType(.numberPad)
                                .frame(maxWidth: 80)
                                .monospacedDigit()
                            Text("W each").foregroundStyle(.secondary)
                            Spacer()
                            Stepper("x \(item.quantity)", value: $item.quantity, in: 1 ... 500)
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .font(.callout)
                    }
                }
                .onDelete { items.remove(atOffsets: $0) }

                Button("Add a fixture", systemImage: "plus.circle.fill") { showingPicker = true }
                Button("Add a custom load", systemImage: "plus.circle") {
                    items.append(PowerBudget.Item(name: "Load \(items.count + 1)", watts: 1000, quantity: 1))
                }
            } header: {
                Text("Loads")
            } footer: {
                Text("Single phase. Fixture watts are the maker's maximum draw.")
            }

            Section("Supply") {
                Picker("Distro", selection: $distroAmps) {
                    ForEach(Self.distroRatings, id: \.self) { Text("\(Int($0)) A").tag($0) }
                }
                NumberField(title: "Voltage", value: $voltage, unit: "V", places: 0)
            }

            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Ambient", value: "\(Int(ambient)) °C")
                    Slider(value: $ambient, in: 25 ... 60, step: 1)
                }
                if let cable = Cable.recommend(amps: result.totalAmps, ambient: ambient) {
                    ResultRow(title: "Smallest cable", value: "\(cable.csaMm2.formatted()) mm²",
                              detail: "carries \(Cable.deratedCapacity(csaMm2: cable.csaMm2, ambient: ambient).formatted()) A at \(Int(ambient)) °C",
                              tint: .green)
                } else {
                    ResultRow(title: "Smallest cable", value: "Over 25 mm²", tint: .red)
                }
                DisclosureGroup("Capacity table") {
                    ForEach(Cable.ratings) { rating in
                        LabeledContent("\(rating.csaMm2.formatted()) mm²") {
                            Text("\(Cable.deratedCapacity(csaMm2: rating.csaMm2, ambient: ambient).formatted()) A")
                                .monospacedDigit()
                                .foregroundStyle(Cable.deratedCapacity(csaMm2: rating.csaMm2, ambient: ambient) >= result.totalAmps
                                                 ? Color.primary : Color.secondary)
                        }
                    }
                }
            } header: {
                Text("Cable")
            } footer: {
                Text("Indicative figures for flexible cable in free air (BS 7919 / BS 7671 Table 4B1). A guide on set, not an installation design. Voltage drop over long runs isn't included.")
            }
        }
        .navigationTitle(CompanionSection.power.title)
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                Form {
                    FixturePickerRow(library: library, fixtureID: $addingFixtureID, noneTitle: "Choose a fixture")
                }
                .navigationTitle("Add Fixture")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onChange(of: addingFixtureID) { _, id in
            guard let id, let fixture = library.fixture(id: id) else { return }
            items.append(PowerBudget.Item(name: fixture.model, watts: fixture.powerW ?? 0, quantity: 1))
            addingFixtureID = nil
            showingPicker = false
        }
    }

    private var loadGauge: some View {
        let fraction = distroAmps > 0 ? result.totalAmps / distroAmps : 0
        let colour: Color = fraction > 1 ? .red : fraction > 0.8 ? .orange : .green
        return HStack(spacing: 20) {
            Gauge(value: min(fraction, 1)) {
                Text("Load")
            } currentValueLabel: {
                Text("\(Int((fraction * 100).rounded()))%")
                    .contentTransition(.numericText())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(colour)
            .scaleEffect(1.6)
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(result.totalAmps.formatted()) A")
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text("\(result.totalWatts.formatted()) W at \(Int(voltage)) V on a \(Int(distroAmps)) A distro")
                    .foregroundStyle(.secondary)
                if let excess = result.excessAmps {
                    Label("\(excess.formatted()) A over", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 20))
        .animation(.snappy, value: result)
    }
}
