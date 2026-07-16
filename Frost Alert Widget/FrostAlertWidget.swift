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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 0) {
                FrostWidgetMark(size: 34)
                Spacer(minLength: 0)
            }

            if let snapshot, let location = primaryLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.risk.shortLabel)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(location.risk.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(location.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FrostWidgetPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(shortLowText(for: location))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(FrostWidgetPalette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
                Text(shortFreshnessText(for: snapshot))
                    .font(.system(size: 13, weight: .medium))
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
        VStack(alignment: .leading, spacing: 13) {
            WidgetHeader(snapshot: snapshot, compact: false)

            if let snapshot, !snapshot.locations.isEmpty {
                VStack(spacing: 11) {
                    ForEach(snapshot.locations.prefix(3)) { location in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(location.name)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(FrostWidgetPalette.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text(shortLowText(for: location) + " | Frost: " + location.frostPeriod)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(FrostWidgetPalette.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            Spacer(minLength: 6)
                            Text(location.risk.shortLabel)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(location.risk.color)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.55)
                                .frame(width: 104, alignment: .trailing)
                        }
                    }
                }

                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(shortFreshnessText(for: snapshot))
                    Text("Covers to \(snapshot.coverageEnd.formatted(date: .omitted, time: .shortened))")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            } else {
                EmptyWidgetContent()
            }
        }
        .padding(18)
    }
}

private struct WidgetHeader: View {
    var snapshot: FrostWidgetSnapshot?
    var compact: Bool

    var body: some View {
        HStack(spacing: 7) {
            FrostWidgetMark(size: compact ? 26 : 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Frost Alert")
                    .font((compact ? Font.caption : Font.title3).weight(.bold))
                    .foregroundStyle(FrostWidgetPalette.ink)
                    .lineLimit(1)
                if let snapshot {
                    Text(snapshot.isStale ? "Needs refresh" : "Latest forecast")
                        .font(compact ? .caption2 : .callout)
                        .foregroundStyle(snapshot.isStale ? FrostWidgetPalette.watch : FrostWidgetPalette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
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
