import SwiftUI
import WidgetKit

struct FrostAlertWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FrostWidgetSnapshot?
}

struct FrostAlertWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FrostAlertWidgetEntry {
        FrostAlertWidgetEntry(
            date: Date(),
            snapshot: FrostWidgetSnapshot(
                generatedAt: Date(),
                coverageEnd: Date().addingTimeInterval(36 * 60 * 60),
                highestRisk: .watch,
                locations: [
                    FrostWidgetLocationSnapshot(
                        id: UUID(),
                        name: "Home",
                        crop: "Grapes",
                        risk: .watch,
                        expectedLowCelsius: 2.4,
                        frostPeriod: "None"
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FrostAlertWidgetEntry) -> Void) {
        completion(FrostAlertWidgetEntry(date: Date(), snapshot: FrostWidgetStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FrostAlertWidgetEntry>) -> Void) {
        let entry = FrostAlertWidgetEntry(date: Date(), snapshot: FrostWidgetStore.loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct FrostAlertWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FrostAlertWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                FrostMediumWidget(snapshot: entry.snapshot)
            default:
                FrostSmallWidget(snapshot: entry.snapshot)
            }
        }
        .containerBackground(FrostWidgetPalette.background, for: .widget)
        .widgetURL(URL(string: "frostalert://dashboard"))
    }
}

private struct FrostSmallWidget: View {
    var snapshot: FrostWidgetSnapshot?

    private var primaryLocation: FrostWidgetLocationSnapshot? {
        snapshot?.rankedLocations.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot, let location = primaryLocation {
                HStack(alignment: .center, spacing: 8) {
                    FrostWidgetMark(size: 28)
                    Text("Frost Alert")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FrostWidgetPalette.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                RiskBadgeText(risk: location.risk, size: .large)
                    .padding(.bottom, 4)

                Text(location.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FrostWidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(shortLowText(for: location))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FrostWidgetPalette.secondary)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text(shortFreshnessText(for: snapshot))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                EmptyWidgetContent()
            }
        }
        .padding(16)
    }
}

private struct FrostMediumWidget: View {
    var snapshot: FrostWidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot, !snapshot.locations.isEmpty {
                MediumHeader(snapshot: snapshot)
                if snapshot.locations.count == 1, let location = snapshot.locations.first {
                    SingleLocationMediumContent(location: location)
                } else {
                    MultiLocationMediumContent(locations: snapshot.rankedLocations)
                }
                MediumFooter(snapshot: snapshot)
            } else {
                EmptyWidgetContent()
            }
        }
        .padding(18)
    }
}

private struct MediumHeader: View {
    var snapshot: FrostWidgetSnapshot?

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            FrostWidgetMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Frost Alert")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FrostWidgetPalette.ink)
                    .lineLimit(1)
                if let snapshot {
                    Text(snapshot.isStale ? "Needs refresh" : "Latest forecast")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SingleLocationMediumContent: View {
    var location: FrostWidgetLocationSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(location.name)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(FrostWidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Text(shortLowText(for: location))
                    Text("Frost: \(location.frostPeriod)")
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(FrostWidgetPalette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            RiskBadgeText(risk: location.risk, size: .medium)
                .frame(maxWidth: 128, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MultiLocationMediumContent: View {
    var locations: [FrostWidgetLocationSnapshot]

    var body: some View {
        VStack(spacing: 9) {
            ForEach(locations.prefix(3)) { location in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FrostWidgetPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(shortLowText(for: location) + " | Frost: " + location.frostPeriod)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FrostWidgetPalette.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 8)

                    RiskBadgeText(risk: location.risk, size: .compact)
                        .frame(width: 96, alignment: .trailing)
                }
            }
        }
    }
}

private struct MediumFooter: View {
    var snapshot: FrostWidgetSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Text(shortFreshnessText(for: snapshot))
            Text("Covers to \(snapshot.coverageEnd.formatted(date: .omitted, time: .shortened))")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct RiskBadgeText: View {
    enum Size {
        case compact
        case medium
        case large
    }

    var risk: FrostWidgetRiskLevel
    var size: Size

    var body: some View {
        Text(risk.shortLabel)
            .font(font)
            .foregroundStyle(risk.color)
            .lineLimit(2)
            .minimumScaleFactor(0.62)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var font: Font {
        switch size {
        case .compact:
            return .system(size: 16, weight: .bold, design: .rounded)
        case .medium:
            return .system(size: 30, weight: .bold, design: .rounded)
        case .large:
            return .system(size: 29, weight: .bold, design: .rounded)
        }
    }
}

private struct FrostWidgetMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.73, green: 0.88, blue: 1), FrostWidgetPalette.accent.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "snowflake")
                .font(.system(size: size * 0.54, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct EmptyWidgetContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No forecast yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FrostWidgetPalette.ink)
            Text("Open Frost Alert to add a location and refresh alerts.")
                .font(.caption2)
                .foregroundStyle(FrostWidgetPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func lowText(for location: FrostWidgetLocationSnapshot) -> String {
    guard let low = location.expectedLowCelsius else {
        return "Low unavailable"
    }
    return "Low \(low.formatted(.number.precision(.fractionLength(0...1)))) C"
}

private func shortLowText(for location: FrostWidgetLocationSnapshot) -> String {
    guard let low = location.expectedLowCelsius else {
        return "Low unavailable"
    }
    return "\(low.formatted(.number.precision(.fractionLength(0...1)))) C low"
}

private func freshnessText(for snapshot: FrostWidgetSnapshot) -> String {
    let relative = snapshot.generatedAt.formatted(.relative(presentation: .named))
    return "Updated \(relative)"
}

private func shortFreshnessText(for snapshot: FrostWidgetSnapshot) -> String {
    if snapshot.isStale {
        return "Needs refresh"
    }
    let minutes = max(0, Int(Date().timeIntervalSince(snapshot.generatedAt) / 60))
    if minutes < 1 {
        return "Updated now"
    }
    if minutes < 60 {
        return "Updated \(minutes)m ago"
    }
    let hours = max(1, minutes / 60)
    return "Updated \(hours)h ago"
}

private extension FrostWidgetSnapshot {
    var rankedLocations: [FrostWidgetLocationSnapshot] {
        locations.sorted {
            if $0.risk.sortOrder == $1.risk.sortOrder {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.risk.sortOrder > $1.risk.sortOrder
        }
    }
}

private enum FrostWidgetPalette {
    static let background = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.20)
    static let secondary = Color(uiColor: .secondaryLabel)
    static let safe = Color(red: 0.15, green: 0.47, blue: 0.30)
    static let watch = Color(red: 0.62, green: 0.42, blue: 0.07)
    static let frost = Color(red: 0.02, green: 0.27, blue: 0.66)
    static let severe = Color(red: 0.01, green: 0.16, blue: 0.42)
    static let accent = Color(red: 0.06, green: 0.35, blue: 0.67)
}

private extension FrostWidgetRiskLevel {
    var shortLabel: String {
        switch self {
        case .frostLikely: "Frost likely"
        case .severe: "Severe"
        default: rawValue
        }
    }

    var color: Color {
        switch self {
        case .safe: FrostWidgetPalette.safe
        case .watch: FrostWidgetPalette.watch
        case .frostLikely: FrostWidgetPalette.frost
        case .severe: FrostWidgetPalette.severe
        case .unavailable: FrostWidgetPalette.secondary
        }
    }
}

@main
struct FrostAlertWidget: Widget {
    let kind = FrostWidgetStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrostAlertWidgetProvider()) { entry in
            FrostAlertWidgetView(entry: entry)
        }
        .configurationDisplayName("Frost Alert")
        .description("Shows the latest frost risk from your saved growing locations.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    FrostAlertWidget()
} timeline: {
    FrostAlertWidgetEntry(
        date: Date(),
        snapshot: FrostWidgetSnapshot(
            generatedAt: Date(),
            coverageEnd: Date().addingTimeInterval(36 * 60 * 60),
            highestRisk: .frostLikely,
            locations: [
                FrostWidgetLocationSnapshot(id: UUID(), name: "Queenstown", crop: "Grapes", risk: .severe, expectedLowCelsius: -1.4, frostPeriod: "1:00 AM-7:00 AM"),
                FrostWidgetLocationSnapshot(id: UUID(), name: "Home", crop: "Citrus", risk: .safe, expectedLowCelsius: 5.6, frostPeriod: "None")
            ]
        )
    )
}
