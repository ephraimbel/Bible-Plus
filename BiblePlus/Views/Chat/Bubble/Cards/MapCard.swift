import SwiftUI
import MapKit

// MARK: - Map / Geography Card
//
// Shows WHERE something in scripture happened — the complement to the timeline
// card's WHEN. The AI hands us a place ("Capernaum") or a journey ("paul-first")
// plus a one-line caption; the card resolves it against the BiblicalAtlas and
// renders a clean, static map preview with a gold pin (or a gold journey line),
// which taps open to a full interactive map.
//
//   [MAP place="Capernaum"]Jesus made this fishing town his ministry base.[/MAP]
//   [MAP journey="paul-first"]Paul's first missionary journey, ~AD 46–48.[/MAP]
struct MapCard: View {
    let place: String
    let journey: String
    let caption: String

    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var showFullMap = false

    private var resolvedJourney: BiblicalJourney? { journey.isEmpty ? nil : BiblicalAtlas.journey(journey) }
    private var resolvedPlace: BiblicalPlace? { place.isEmpty ? nil : BiblicalAtlas.place(place) }

    private var coordinates: [CLLocationCoordinate2D] {
        if let j = resolvedJourney { return j.stops.map { .init(latitude: $0.lat, longitude: $0.lon) } }
        if let p = resolvedPlace { return [.init(latitude: p.lat, longitude: p.lon)] }
        return []
    }

    private var title: String {
        resolvedJourney?.name ?? resolvedPlace?.name ?? (place.isEmpty ? journey : place)
    }

    private var hasMap: Bool { !coordinates.isEmpty }

    var body: some View {
        Group {
            if hasMap { mapCard } else { fallbackCard }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [palette.accent.opacity(0.34), palette.accent.opacity(0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .blur(radius: 18)
                .offset(y: 7)
        )
        .padding(.vertical, 10)
        .sheet(isPresented: $showFullMap) { fullMapSheet }
    }

    // MARK: Assembled card

    private var mapCard: some View {
        VStack(spacing: 0) {
            header
            mapPreview
            if !caption.isEmpty {
                Text(caption)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 10, weight: .semibold))
                Text(resolvedJourney != nil ? "THE JOURNEY" : "ON THE MAP")
                    .font(.system(size: 9.5, weight: .semibold)).tracking(2.2)
            }
            .foregroundStyle(palette.accent.opacity(0.78))
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var mapPreview: some View {
        // A static SNAPSHOT (not a live Map) so there's no Apple logo / Legal
        // chrome — just the clean map. The pin / route are drawn on top.
        MapSnapshotView(region: region, stops: coordinates, accent: palette.accent, colorScheme: colorScheme)
            .frame(height: 178)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
                    .padding(7)
                    .background(Circle().fill(.ultraThinMaterial))
                    .padding(10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticService.lightImpact()
                showFullMap = true
            }
    }

    // MARK: Map content (shared by preview + sheet)

    private func mapContent(interactive: Bool) -> some View {
        Map(initialPosition: .region(region), interactionModes: interactive ? .all : []) {
            if let j = resolvedJourney {
                MapPolyline(coordinates: coordinates)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(j.stops.enumerated()), id: \.offset) { index, stop in
                    Annotation("", coordinate: .init(latitude: stop.lat, longitude: stop.lon)) {
                        journeyDot(isEndpoint: index == 0 || index == j.stops.count - 1)
                    }
                }
            } else if let p = resolvedPlace {
                Annotation("", coordinate: .init(latitude: p.lat, longitude: p.lon)) {
                    goldPin
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    private var goldPin: some View {
        ZStack {
            Circle().fill(.white).frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            Image(systemName: "mappin")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.accent)
        }
    }

    private func journeyDot(isEndpoint: Bool) -> some View {
        Circle()
            .fill(palette.accent)
            .frame(width: isEndpoint ? 12 : 9, height: isEndpoint ? 12 : 9)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: .init(latitude: 31.77, longitude: 35.21),
                                      span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4))
        }
        if coordinates.count == 1 {
            return MKCoordinateRegion(center: coordinates[0],
                                      span: MKCoordinateSpan(latitudeDelta: 3.4, longitudeDelta: 3.4))
        }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2,
                                            longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.6, 1.2),
                                    longitudeDelta: max((lons.max()! - lons.min()!) * 1.6, 1.2))
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: Full-screen sheet

    private var fullMapSheet: some View {
        ZStack(alignment: .topTrailing) {
            mapContent(interactive: true)
                .ignoresSafeArea()

            Button {
                showFullMap = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .padding(16)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.custom("Georgia", size: 14))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.ultraThinMaterial)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Fallback (place not in the atlas)

    private var fallbackCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? "On the map" : title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                if !caption.isEmpty {
                    Text(caption)
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Static Map Snapshot
//
// Renders the map region as a plain image via MKMapSnapshotter — which, unlike
// a live Map, carries no Apple logo or "Legal" link — then draws the gold pin
// (single place) or gold route + stop dots (journey) on top, positioned using
// the snapshot's coordinate→point conversion.
private struct MapSnapshotView: View {
    let region: MKCoordinateRegion
    let stops: [CLLocationCoordinate2D]
    let accent: Color
    let colorScheme: ColorScheme

    @State private var image: UIImage?
    @State private var points: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                    overlay
                } else {
                    Rectangle().fill(accent.opacity(0.06))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: "\(Int(geo.size.width))x\(Int(geo.size.height))") {
                await generate(size: geo.size)
            }
        }
    }

    @ViewBuilder private var overlay: some View {
        if points.count > 1 {
            Path { path in
                path.move(to: points[0])
                for point in points.dropFirst() { path.addLine(to: point) }
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                let isEndpoint = index == 0 || index == points.count - 1
                Circle()
                    .fill(accent)
                    .frame(width: isEndpoint ? 12 : 9, height: isEndpoint ? 12 : 9)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .position(point)
            }
        } else if let point = points.first {
            ZStack {
                Circle().fill(.white).frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                Image(systemName: "mappin")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            .position(point)
        }
    }

    // MKMapSnapshotter bakes the Apple logo + "Legal" link into the bottom of
    // the image. We render the map a little taller and crop that bottom strip
    // away (cropping from the bottom keeps the top-left origin, so the pin /
    // route points stay aligned), leaving just the map.
    private let brandingMargin: CGFloat = 26

    private func generate(size: CGSize) async {
        guard size.width > 1, size.height > 1 else { return }
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: size.width, height: size.height + brandingMargin)
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return }
        let converted = stops.map { snapshot.point(for: $0) }
        let trimmed = Self.cropFromTop(snapshot.image, toHeight: size.height)
        await MainActor.run {
            self.image = trimmed
            self.points = converted
        }
    }

    private static func cropFromTop(_ image: UIImage, toHeight height: CGFloat) -> UIImage {
        let scale = image.scale
        let rect = CGRect(x: 0, y: 0, width: image.size.width * scale, height: height * scale)
        guard let cropped = image.cgImage?.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}
