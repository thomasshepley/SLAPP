// Companion/Views/PhotometryCard.swift
import Charts
import SwiftUI

/// Lux and beam size at a chosen distance, with the falloff curve drawn.
struct PhotometryCard: View {
    let luxAt1m: Double
    let beamAngle: Double?
    @Binding var distance: Double
    let units: CompanionUnits
    var maxDistance: Double = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("At a distance")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                StatTile(title: "Distance", value: units.distance.text(distance, places: 1),
                         symbol: "ruler", tint: .secondary)
                StatTile(title: "Illuminance",
                         value: units.illuminance.text(Photometry.lux(atDistance: distance, luxAt1m: luxAt1m)),
                         symbol: "sun.max.fill", tint: .yellow)
                if let beamAngle {
                    StatTile(title: "Beam diameter",
                             value: units.distance.text(Photometry.beamDiameter(angle: beamAngle, distance: distance), places: 1),
                             symbol: "circle.dashed", tint: .orange)
                }
            }

            Slider(value: $distance, in: 0.5 ... maxDistance, step: 0.1) {
                Text("Distance")
            } minimumValueLabel: {
                Text(units.distance.text(0.5, places: 1)).font(.caption)
            } maximumValueLabel: {
                Text(units.distance.text(maxDistance, places: 0)).font(.caption)
            }

            if let range = luxRange {
                chart(range)
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 20))
    }

    /// The falloff curve on a log scale. Log scales can't show 0, so the
    /// shading starts at the bottom of an explicit, always-positive range
    /// rather than the default baseline of 0 (which crashed Swift Charts).
    private func chart(_ range: ClosedRange<Double>) -> some View {
        let here = units.illuminance.display(Photometry.lux(atDistance: distance, luxAt1m: luxAt1m))
        return Chart {
            ForEach(curve) { point in
                AreaMark(x: .value("Distance", units.distance.display(point.distance)),
                         yStart: .value("Lux", range.lowerBound),
                         yEnd: .value("Lux", units.illuminance.display(point.lux)))
                    .foregroundStyle(.linearGradient(colors: [.yellow.opacity(0.35), .yellow.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Distance", units.distance.display(point.distance)),
                         y: .value("Lux", units.illuminance.display(point.lux)))
                    .foregroundStyle(.yellow)
                    .interpolationMethod(.catmullRom)
            }
            RuleMark(x: .value("Here", units.distance.display(distance)))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            PointMark(x: .value("Here", units.distance.display(distance)),
                      y: .value("Lux", min(max(here, range.lowerBound), range.upperBound)))
                .foregroundStyle(.orange)
                .symbolSize(80)
        }
        .chartYScale(domain: range, type: .log)
        .chartXAxisLabel(units.distance.unit)
        .chartYAxisLabel(units.illuminance.unit)
        .frame(height: 200)
    }

    /// Display-unit lux from the far end of the slider to the near end, with
    /// some headroom. Nil when there's nothing positive to draw.
    private var luxRange: ClosedRange<Double>? {
        let far = units.illuminance.display(Photometry.lux(atDistance: maxDistance, luxAt1m: luxAt1m))
        let near = units.illuminance.display(Photometry.lux(atDistance: 0.5, luxAt1m: luxAt1m))
        guard far.isFinite, near.isFinite, far > 0, near > far else { return nil }
        return (far / 2) ... (near * 1.5)
    }

    private struct Point: Identifiable {
        let distance: Double
        let lux: Double
        var id: Double { distance }
    }

    private var curve: [Point] {
        stride(from: 0.5, through: maxDistance, by: 0.25).map {
            Point(distance: $0, lux: Photometry.lux(atDistance: $0, luxAt1m: luxAt1m))
        }
    }
}
