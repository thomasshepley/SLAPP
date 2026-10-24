// Companion/Views/SunToolView.swift
import Charts
import CoreLocation
import MapKit
import SwiftUI

/// Where the sun is for a spot on the map at any time of day: tap the map
/// (or search, or use your location), scrub the time slider, and see the
/// sun's direction drawn from the spot, plus golden and blue hour.
struct SunToolView: View {
    @AppStorage("companion.sun.latitude") private var latitude: Double = 51.5074
    @AppStorage("companion.sun.longitude") private var longitude: Double = -0.1278
    @AppStorage("companion.sun.placeName") private var placeName: String = "London"
    @State private var day = Date()
    /// Minutes from the location's midnight.
    @State private var minutes: Double = SunToolView.minutesNow(in: .current)
    @State private var timeZone: TimeZone = .current
    @State private var camera: MapCameraPosition = .automatic
    @State private var search = ""
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var message: String?

    private var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    private var location: Sun.Location {
        Sun.Location(latitude: latitude, longitude: longitude,
                     utcOffsetHours: Double(timeZone.secondsFromGMT(for: moment)) / 3600)
    }
    private var times: Sun.Times { Sun.times(on: moment, at: location) }
    private var position: Sun.Position { Sun.position(at: moment, location: location) }

    /// The chosen day at the slider's time, in the location's time zone.
    private var moment: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: day).addingTimeInterval(minutes * 60)
    }

    var body: some View {
        Form {
            Section {
                map
                    .frame(height: 340)
                    .listRowInsets(EdgeInsets())
                HStack {
                    TextField("Search for a place", text: $search)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { Task { await searchPlace() } }
                    if isSearching { ProgressView() }
                    Button {
                        Task { await useMyLocation() }
                    } label: {
                        if isLocating { ProgressView() } else { Image(systemName: "location.fill") }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Use my location")
                }
                if let message {
                    Text(message).font(.callout).foregroundStyle(.orange)
                }
            } header: {
                Text("Where")
            } footer: {
                Text("\(placeName) · \(latitude.formatted(.number.precision(.fractionLength(4)))), \(longitude.formatted(.number.precision(.fractionLength(4)))) · times in \(timeZone.localizedName(for: .shortGeneric, locale: .current) ?? timeZone.identifier). Tap the map to move the pin.")
            }

            Section {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                timeSlider
                HStack(spacing: 8) {
                    jump("Sunrise", times.sunrise)
                    jump("Golden", times.goldenEvening?.start)
                    jump("Noon", times.solarNoon)
                    jump("Sunset", times.sunset)
                    Button("Now") {
                        day = Date()
                        withAnimation { minutes = Self.minutesNow(in: timeZone) }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
                HStack(spacing: 12) {
                    StatTile(title: "Sun bearing", value: "\(Int(position.azimuth.rounded()))° \(Self.compass(position.azimuth))",
                             symbol: "location.north.line.fill", tint: .orange)
                    StatTile(title: "Height", value: "\(Int(position.elevation.rounded()))°",
                             symbol: position.elevation > 0 ? "sun.max.fill" : "moon.fill",
                             tint: position.elevation > 0 ? .yellow : .indigo)
                    StatTile(title: "Shadows", value: position.elevation > 0 ? shadowText : "-",
                             symbol: "figure.stand", tint: .secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("When")
            }

            Section {
                timeRow("Sunrise", times.sunrise, symbol: "sunrise.fill", tint: .orange)
                windowRow("Golden hour (morning)", times.goldenMorning, tint: .yellow)
                windowRow("Golden hour (evening)", times.goldenEvening, tint: .yellow)
                timeRow("Sunset", times.sunset, symbol: "sunset.fill", tint: .orange)
                windowRow("Blue hour (morning)", times.blueMorning, tint: .blue)
                windowRow("Blue hour (evening)", times.blueEvening, tint: .blue)
            } header: {
                Text("The day")
            }
        }
        .navigationTitle(CompanionSection.sun.title)
        .task { await updateTimeZone() }
    }

    // MARK: - Map

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                Annotation(placeName, coordinate: coordinate, anchor: .center) {
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.orange, lineWidth: 3))
                        .shadow(radius: 3)
                }
                if let rise = bearing(at: times.sunrise) {
                    MapPolyline(coordinates: line(bearing: rise, metres: lineLength))
                        .stroke(.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                }
                if let set = bearing(at: times.sunset) {
                    MapPolyline(coordinates: line(bearing: set, metres: lineLength))
                        .stroke(.orange.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                }
                if position.elevation > -6 {
                    MapPolyline(coordinates: line(bearing: position.azimuth, metres: lineLength * 1.15))
                        .stroke(position.elevation > 0 ? Color.yellow : Color.indigo, lineWidth: 6)
                    Annotation("Sun", coordinate: end(bearing: position.azimuth, metres: lineLength * 1.15)) {
                        Image(systemName: position.elevation > 0 ? "sun.max.fill" : "sun.horizon.fill")
                            .font(.title2)
                            .foregroundStyle(position.elevation > 0 ? .yellow : .indigo)
                            .shadow(radius: 2)
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                guard let picked = proxy.convert(point, from: .local) else { return }
                move(to: picked, name: "Dropped pin")
            }
        }
        .onAppear {
            camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000))
        }
    }

    /// Long enough to read at street scale.
    private var lineLength: Double { 600 }

    private func bearing(at minutes: Double?) -> Double? {
        guard let minutes else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.startOfDay(for: day).addingTimeInterval(minutes * 60)
        return Sun.position(at: date, location: location).azimuth
    }

    private func end(bearing: Double, metres: Double) -> CLLocationCoordinate2D {
        let point = Sun.destination(latitude: latitude, longitude: longitude, bearing: bearing, metres: metres)
        return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private func line(bearing: Double, metres: Double) -> [CLLocationCoordinate2D] {
        [coordinate, end(bearing: bearing, metres: metres)]
    }

    private func move(to coordinate: CLLocationCoordinate2D, name: String, recentre: Bool = false) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        placeName = name
        message = nil
        if recentre {
            withAnimation {
                camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000))
            }
        }
        Task { await updateTimeZone() }
    }

    // MARK: - Time

    private var timeSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Time") {
                Text(moment.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            ZStack {
                dayBands
                    .frame(height: 10)
                    .clipShape(.capsule)
                Slider(value: $minutes, in: 0 ... 1439, step: 1)
                    .tint(.clear)
            }
            HStack {
                ForEach(["00:00", "06:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                    if label != "24:00" { Spacer() }
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    /// Night, blue, golden and daylight across 24 hours: the slider's track.
    private var dayBands: some View {
        var bands: [(start: Double, end: Double, colour: Color)] = []
        if let rise = times.sunrise, let set = times.sunset { bands.append((rise, set, .cyan.opacity(0.7))) }
        for (window, colour) in [(times.blueMorning, Color.blue), (times.blueEvening, .blue),
                                 (times.goldenMorning, .yellow), (times.goldenEvening, .yellow)] {
            if let window { bands.append((min(window.start, window.end), max(window.start, window.end), colour)) }
        }
        return Chart {
            RectangleMark(xStart: .value("Start", 0.0), xEnd: .value("End", 1440.0))
                .foregroundStyle(.indigo.opacity(0.6))
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                RectangleMark(xStart: .value("Start", band.start), xEnd: .value("End", band.end))
                    .foregroundStyle(band.colour)
            }
        }
        .chartXScale(domain: 0.0 ... 1440.0)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.frame(maxWidth: .infinity) }
        .allowsHitTesting(false)
    }

    private func jump(_ title: String, _ target: Double?) -> some View {
        Button(title) {
            if let target { withAnimation { minutes = min(1439, max(0, target.rounded())) } }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(target == nil)
    }

    private var shadowText: String {
        let length = 1 / tan(position.elevation * .pi / 180)
        return "\(length.formatted(.number.precision(.fractionLength(1))))x height"
    }

    private func clock(_ minutes: Double) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.startOfDay(for: day).addingTimeInterval(minutes * 60)
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
    }

    @ViewBuilder
    private func timeRow(_ title: String, _ minutes: Double?, symbol: String, tint: Color) -> some View {
        LabeledContent {
            Text(minutes.map(clock) ?? "None today").monospacedDigit()
        } label: {
            Label(title, systemImage: symbol).foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func windowRow(_ title: String, _ window: Sun.Window?, tint: Color) -> some View {
        LabeledContent {
            Text(window.map { "\(clock($0.start)) - \(clock($0.end))" } ?? "None today").monospacedDigit()
        } label: {
            Label(title, systemImage: "circle.fill").foregroundStyle(tint)
        }
    }

    // MARK: - Place, location and time zone

    private func searchPlace() async {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                message = "Couldn't find \(query)."
                return
            }
            if let zone = item.timeZone { timeZone = zone }
            move(to: item.placemark.coordinate, name: item.name ?? query, recentre: true)
        } catch {
            message = "Search needs an internet connection."
        }
    }

    private func useMyLocation() async {
        isLocating = true
        defer { isLocating = false }
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    message = "Location is off for TitanDeck. Turn it on in Settings > Privacy > Location Services."
                    return
                }
                if let found = update.location {
                    move(to: found.coordinate, name: "My location", recentre: true)
                    return
                }
            }
        } catch {
            message = "Couldn't get your location."
        }
    }

    /// Times read in the location's own time zone (looked up from the map).
    private func updateTimeZone() async {
        let place = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(place).first else { return }
        if let zone = placemark.timeZone, zone != timeZone {
            timeZone = zone   // minutes stay as the wall-clock time at the new place
        }
        if placeName == "Dropped pin", let name = placemark.locality ?? placemark.name {
            placeName = name
        }
    }

    static func minutesNow(in zone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: Date())
        return Double((parts.hour ?? 12) * 60 + (parts.minute ?? 0))
    }

    static func compass(_ bearing: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return points[Int((bearing / 45).rounded()) % 8]
    }
}
