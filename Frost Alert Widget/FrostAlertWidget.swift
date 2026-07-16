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
        snapshot?.locations.max { $0.risk.sortOrder < $1.risk.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(snapshot: snapshot, compact: true)
            Spacer(minLength: 2)

            if let snapshot, let location = primaryLocation {
                Text(location.risk.rawValue)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(location.risk.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FrostWidgetPalette.ink)
                        .lineLimit(1)
                    Text(lowText(for: location))
                        .font(.caption2)
                        .foregroundStyle(FrostWidgetPalette.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)
                Text(freshnessText(for: snapshot))
                    .font(.caption2)
                    .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                    .lineLimit(1)
            } else {
                EmptyWidgetContent()
            }
        }
        .padding()
    }
}

private struct FrostMediumWidget: View {
    var snapshot: FrostWidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(snapshot: snapshot, compact: false)

            if let snapshot, !snapshot.locations.isEmpty {
                VStack(spacing: 7) {
                    ForEach(snapshot.locations.prefix(3)) { location in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FrostWidgetPalette.ink)
                                    .lineLimit(1)
                                Text(lowText(for: location) + " | Frost: " + location.frostPeriod)
                                    .font(.caption2)
                                    .foregroundStyle(FrostWidgetPalette.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text(location.risk.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(location.risk.color)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }

                Spacer(minLength: 2)
                Text(freshnessText(for: snapshot) + " | Covers through " + snapshot.coverageEnd.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                    .lineLimit(1)
            } else {
                EmptyWidgetContent()
            }
        }
        .padding()
    }
}

private struct WidgetHeader: View {
    var snapshot: FrostWidgetSnapshot?
    var compact: Bool

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.73, green: 0.88, blue: 1), FrostWidgetPalette.accent.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "snowflake")
                    .font(.system(size: compact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Frost Alert")
                    .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                    .foregroundStyle(FrostWidgetPalette.ink)
                    .lineLimit(1)
                if let snapshot {
                    Text(snapshot.isStale ? "Needs refresh" : "Latest forecast")
                        .font(.caption2)
                        .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
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

private func freshnessText(for snapshot: FrostWidgetSnapshot) -> String {
    let relative = snapshot.generatedAt.formatted(.relative(presentation: .named))
    return "Updated \(relative)"
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
