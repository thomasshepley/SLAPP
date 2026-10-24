// Companion/Views/GelLibraryView.swift
import SwiftUI

/// Every LEE, Rosco and GAM filter as a swatch book: search, filter by range
/// and type, tap a swatch for its numbers and lookalikes in other ranges.
struct GelLibraryView: View {
    let library: FixtureLibrary
    @State private var search = ""
    @State private var range: String?
    @State private var category: Gel.Category?
    @State private var selected: Gel?

    private var results: [Gel] { library.gels(matching: search, range: range, category: category) }

    private var grouped: [(range: String, gels: [Gel])] {
        var order: [String] = []
        var groups: [String: [Gel]] = [:]
        for gel in results {
            let key = gel.range ?? gel.manufacturer
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(gel)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                filters
                ForEach(grouped, id: \.range) { group in
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                            ForEach(group.gels) { gel in
                                Button { selected = gel } label: { GelSwatchTile(gel: gel) }
                                    .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.range).font(.headline)
                            Spacer()
                            Text("\(group.gels.count)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(.bar)
                    }
                }
                Text("\(results.count) of \(library.gels.count) filters. Swatch colours are the manufacturers' own, and only approximate on screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: search) }
        }
        .searchable(text: $search, prompt: "Number or name, e.g. 201 or straw")
        .navigationTitle("Gels")
        .sheet(item: $selected) { gel in
            NavigationStack {
                GelDetailView(gel: gel, library: library) { selected = $0 }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("All ranges", isOn: range == nil) { range = nil }
                    ForEach(library.gelRanges, id: \.self) { name in
                        chip(name, isOn: range == name) { range = range == name ? nil : name }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("All types", isOn: category == nil) { category = nil }
                    ForEach(Gel.Category.allCases) { kind in
                        chip(kind.title, isOn: category == kind) { category = category == kind ? nil : kind }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(title) { withAnimation(.snappy) { action() } }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isOn ? Color.accentColor : Color.secondary)
            .controlSize(.small)
    }
}

/// One swatch: the colour, its number and name, and how much light it passes.
struct GelSwatchTile: View {
    let gel: Gel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(gel: gel))
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                .overlay(alignment: .bottomTrailing) {
                    if let t = gel.transmission {
                        Text("\(Int(t.rounded()))%")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: .capsule)
                            .padding(5)
                    }
                }
            Text(gel.number)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .padding(.top, 6)
            Text(gel.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// A filter's details, and the closest colours in the other ranges.
struct GelDetailView: View {
    let gel: Gel
    let library: FixtureLibrary
    let open: (Gel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(gel: gel))
                    .frame(height: 140)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator))
                    .shadow(color: Color(gel: gel).opacity(0.5), radius: 16, y: 6)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                VStack(alignment: .leading, spacing: 4) {
                    Text(gel.displayNumber).font(.title2.weight(.bold))
                    Text(gel.name).font(.title3)
                    if let description = gel.description {
                        Text(description).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if let category = gel.category { LabeledContent("Type", value: category.title) }
                if let t = gel.transmission {
                    LabeledContent(gel.transmissionDaylight == nil ? "Transmission" : "Transmission (tungsten)",
                                   value: "\(t.formatted(.number.precision(.fractionLength(0 ... 1))))%")
                }
                if let t = gel.transmissionDaylight {
                    LabeledContent("Transmission (daylight)", value: "\(t.formatted(.number.precision(.fractionLength(0 ... 1))))%")
                }
                if let stops = gel.stopLoss {
                    LabeledContent("Light lost", value: "\(stops.formatted(.number.precision(.fractionLength(1)))) stops")
                }
                if let mired = gel.miredShift {
                    LabeledContent("Mired shift", value: "\(mired > 0 ? "+" : "")\(Int(mired))")
                }
                LabeledContent("Swatch", value: ColourMaths.hex(gel.rgb)).monospaced()
                if let link = gel.source.flatMap(URL.init(string:)) {
                    Link("Manufacturer's page", destination: link)
                }
            }

            let similar = library.nearestGels(to: gel.rgb, count: 5, excluding: gel.id, otherThan: gel.range ?? gel.manufacturer)
            if gel.category == .colour, !similar.isEmpty {
                Section {
                    ForEach(similar) { other in
                        Button { open(other) } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(gel: other))
                                    .frame(width: 40, height: 40)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                                VStack(alignment: .leading) {
                                    Text(other.displayNumber).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                                    Text(other.name).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let t = other.transmission {
                                    Text("\(Int(t.rounded()))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Looks like")
                } footer: {
                    Text("Closest swatches in the other ranges. Check the real gel before swapping on a show.")
                }
            }
        }
        .navigationTitle(gel.displayNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { dismiss() }
            }
        }
    }
}

extension Color {
    init(gel: Gel) {
        self.init(red: Double(gel.swatchRgb.r) / 255, green: Double(gel.swatchRgb.g) / 255, blue: Double(gel.swatchRgb.b) / 255)
    }
}
