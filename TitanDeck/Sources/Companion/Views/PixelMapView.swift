// Companion/Views/PixelMapView.swift
import SwiftUI

/// A pixel mode drawn over the fixture's face: every pixel coloured by the
/// cell that drives it, with the cell numbers on top. Tap a cell to see its
/// DMX channels (the chart below highlights them too).
struct PixelMapView: View {
    let layout: PixelLayout
    let cells: [PixelLayout.Cell]
    /// The fixture's own choices for this mode (Zone Orientation), if any.
    var options: [PixelLayout.Option] = []
    @Binding var option: Int
    @Binding var selected: PixelLayout.Cell.ID?
    @State private var group = ""

    private var groups: [String] {
        var seen: [String] = []
        for cell in cells where !seen.contains(cell.group) { seen.append(cell.group) }
        return seen
    }

    private var shown: [PixelLayout.Cell] { cells.filter { $0.group == activeGroup } }
    private var activeGroup: String { groups.contains(group) ? group : groups.first ?? "" }
    private var selectedCell: PixelLayout.Cell? { cells.first { $0.id == selected } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Pixel map", systemImage: "square.grid.3x3.fill")
                    .font(.headline)
                Spacer()
                Text("\(shown.count) cells")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if options.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Picker(layout.variantTitle ?? "Layout", selection: $option) {
                        ForEach(options.indices, id: \.self) { index in
                            Text(options[index].label).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Set on the fixture\(layout.variantTitle.map { " (\($0))" } ?? ""). \(options[min(option, options.count - 1)].note ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if groups.count > 1 {
                Picker("Pixels", selection: $group) {
                    ForEach(groups, id: \.self) { Text($0.isEmpty ? "Pixels" : $0).tag($0) }
                }
                .pickerStyle(.segmented)
                .onAppear { if group.isEmpty { group = groups[0] } }
            }
            PixelFace(layout: layout, cells: shown, selected: $selected)
            selectionInfo
            footer
        }
        .onChange(of: group) { _, _ in selected = nil }
        .onChange(of: option) { _, _ in selected = nil }
    }

    @ViewBuilder
    private var selectionInfo: some View {
        if let cell = selectedCell {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cell.title).font(.subheadline.weight(.semibold))
                    Text("ch \(cell.channelText)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear", systemImage: "xmark.circle.fill") { selected = nil }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                Text(cell.channels.map(\.label).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PixelPalette.colour(for: cell, of: shown.count).opacity(0.15), in: .rect(cornerRadius: 12))
        } else {
            Text("Tap a cell to see the channels that drive it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let orientation = layout.orientation {
                Label(orientation, systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            if layout.cell1Assumed == true {
                Label("The manual doesn't show where cell 1 is, so the order here is a best guess. Check it on the rig.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let notes = layout.notes, !notes.isEmpty {
                Text(notes)
            }
            if let source = layout.source, let url = URL(string: source) {
                Link(destination: url) {
                    Label("Layout from the manual\(layout.page.map { ", \($0)" } ?? "")", systemImage: "book")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Distinct, readable colours for the cells, going round the hue wheel.
enum PixelPalette {
    static func colour(for cell: PixelLayout.Cell, of count: Int) -> Color {
        let steps = max(count, 1)
        // Every other step jumps half way round, so neighbouring cells differ.
        let position = cell.number - 1
        let spread = (position % 2 == 0 ? position / 2 : (steps + 1) / 2 + position / 2)
        return Color(hue: Double(spread) / Double(steps) * 0.92, saturation: 0.6, brightness: 0.95)
    }
}

/// The face itself, drawn on a Canvas so a 141-pixel aura stays smooth.
private struct PixelFace: View {
    let layout: PixelLayout
    let cells: [PixelLayout.Cell]
    @Binding var selected: PixelLayout.Cell.ID?

    @State private var canvasSize: CGSize = .zero

    /// Tubes and bars are drawn at a set thickness; everything else to scale.
    private var isLong: Bool { layout.face.aspect > 5 }

    var body: some View {
        sized(Canvas { context, size in draw(in: &context, size: size) })
            .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
            .contentShape(.rect)
            .gesture(SpatialTapGesture().onEnded { tap in
                let hit = cellAt(tap.location, size: canvasSize)
                withAnimation(.snappy) { selected = hit == selected ? nil : hit }
            })
            .accessibilityElement()
            .accessibilityLabel("Pixel map with \(cells.count) cells")
    }

    @ViewBuilder
    private func sized(_ canvas: some View) -> some View {
        if isLong {
            canvas.frame(maxWidth: .infinity).frame(height: 64)
        } else {
            canvas
                .aspectRatio(max(layout.face.aspect, 0.2), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
        }
    }

    private var cellByPixel: [Int: PixelLayout.Cell] {
        var map: [Int: PixelLayout.Cell] = [:]
        for cell in cells { for id in cell.pixelIDs { map[id] = cell } }
        return map
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let faceRect = CGRect(origin: .zero, size: size)
        let face = shapePath(layout.face.shape, in: faceRect)
        context.fill(face, with: .color(Color(white: 0.12)))
        context.stroke(face, with: .color(Color(white: 0.45)), lineWidth: 1.5)

        let map = cellByPixel
        for pixel in layout.pixels {
            let path = pixelPath(pixel, size: size)
            guard let cell = map[pixel.id] else {
                context.fill(path, with: .color(Color(white: 0.25)))
                continue
            }
            let colour = PixelPalette.colour(for: cell, of: cells.count)
            let dimmed = selected != nil && selected != cell.id
            if pixel.shape == .ring {
                context.stroke(path, with: .color(colour.opacity(dimmed ? 0.3 : 1)),
                               lineWidth: CGFloat(pixel.w ?? 0.05) * size.width)
            } else {
                context.fill(path, with: .color(colour.opacity(dimmed ? 0.3 : 1)))
                context.stroke(path, with: .color(.black.opacity(0.5)), lineWidth: 0.5)
            }
            if selected == cell.id {
                context.stroke(path, with: .color(.white), lineWidth: 2)
            }
        }
        drawNumbers(in: &context, size: size)
    }

    /// Each cell's number at the middle of its pixels, when there's room.
    private func drawNumbers(in context: inout GraphicsContext, size: CGSize) {
        let pixels = Dictionary(uniqueKeysWithValues: layout.pixels.map { ($0.id, $0) })
        let spacing = (Double(size.width * size.height) / Double(max(cells.count, 1))).squareRoot()
        guard spacing >= 14 else { return }
        let fontSize = min(16, max(9, spacing * 0.4))
        for cell in cells {
            let centres = cell.pixelIDs.compactMap { pixels[$0]?.centre }
            guard !centres.isEmpty else { continue }
            let x = centres.map { $0.x }.reduce(0, +) / Double(centres.count) * size.width
            let y = centres.map { $0.y }.reduce(0, +) / Double(centres.count) * size.height
            let dimmed = selected != nil && selected != cell.id
            context.draw(Text("\(cell.number)")
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(dimmed ? 0.4 : 0.85)),
                         at: CGPoint(x: x, y: y))
        }
    }

    private func cellAt(_ point: CGPoint, size: CGSize) -> PixelLayout.Cell.ID? {
        let map = cellByPixel
        // Smallest shapes first, so a pixel inside a ring zone wins.
        for pixel in layout.pixels.reversed() {
            guard let cell = map[pixel.id] else { continue }
            if pixel.shape == .ring {
                let centre = CGPoint(x: pixel.x * size.width, y: pixel.y * size.height)
                let distance = hypot(point.x - centre.x, point.y - centre.y)
                let radius = (pixel.r ?? 0) * size.width
                let half = (pixel.w ?? 0.05) * size.width / 2 + 4
                if abs(distance - radius) <= half { return cell.id }
            } else if pixelPath(pixel, size: size).contains(point) {
                return cell.id
            }
        }
        return nil
    }

    private func pixelPath(_ pixel: PixelLayout.Pixel, size: CGSize) -> Path {
        switch pixel.shape {
        case .rect, .roundedRect, .capsule:
            let rect = CGRect(x: pixel.x * size.width, y: pixel.y * size.height,
                              width: (pixel.w ?? 0) * size.width, height: (pixel.h ?? 0) * size.height)
                .insetBy(dx: 0.75, dy: 0.75)
            return shapePath(pixel.shape, in: rect)
        case .circle, .hexagon, .ring:
            let radius = (pixel.r ?? 0.05) * size.width
            let rect = CGRect(x: pixel.x * size.width - radius, y: pixel.y * size.height - radius,
                              width: radius * 2, height: radius * 2)
            return shapePath(pixel.shape == .ring ? .circle : pixel.shape, in: rect)
        }
    }

    private func shapePath(_ shape: PixelLayout.Shape, in rect: CGRect) -> Path {
        switch shape {
        case .rect: return Path(rect)
        case .roundedRect: return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.08)
        case .capsule: return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
        case .circle, .ring: return Path(ellipseIn: rect)
        case .hexagon:
            var path = Path()
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            for corner in 0 ..< 6 {
                let angle = CGFloat(corner) * .pi / 3 + .pi / 6
                let point = CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
                if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
    }
}
