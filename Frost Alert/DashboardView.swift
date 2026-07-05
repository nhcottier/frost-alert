import SwiftUI
import UserNotifications

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingAddLocation = false

    var body: some View {
        NavigationStack {
            ZStack {
                FrostPalette.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Frost Alert")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add growing location")
                }
            }
            .task {
                await appModel.load()
            }
            .refreshable {
                await appModel.load()
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView { name, crop, sensitivity in
                    appModel.addLocation(name: name, crop: crop, sensitivity: sensitivity)
                    Task { await appModel.load() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appModel.state {
        case .loading:
            LoadingStateView()
        case .empty:
            EmptyStateView {
                showingAddLocation = true
            }
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await appModel.load() }
            }
        case .loaded(let assessments):
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NotificationPermissionBanner()
                    DashboardHeader(assessments: assessments)
                    ForEach(assessments) { assessment in
                        LocationRiskCard(locationAssessment: assessment)
                    }
                    DisclaimerView()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
    }
}

private struct DashboardHeader: View {
    var assessments: [LocationAssessment]

    private var highestRisk: FrostRiskLevel {
        assessments.map(\.assessment.level).max { $0.sortOrder < $1.sortOrder } ?? .safe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tonight and tomorrow morning")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FrostPalette.ink.opacity(0.72))
            Text(highestRisk.rawValue)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(highestRisk.color)
                .minimumScaleFactor(0.8)
            Text("Focused frost guidance for growing locations, not a full weather dashboard.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

private struct LocationRiskCard: View {
    var locationAssessment: LocationAssessment

    private var assessment: FrostRiskAssessment { locationAssessment.assessment }
    private var location: GrowingLocation { locationAssessment.location }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FrostPalette.ink)
                    Text("\(location.crop) - \(location.sensitivity.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                RiskBadge(level: assessment.level)
            }

            VStack(alignment: .leading, spacing: 10) {
                MetricRow(icon: "thermometer.low", label: "Expected low", value: "\(assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))) C")
                MetricRow(icon: "clock", label: "Likely frost window", value: frostWindowText)
                MetricRow(icon: "slider.horizontal.3", label: "Plant threshold", value: "\(location.sensitivity.thresholdCelsius.formatted(.number.precision(.fractionLength(0...1)))) C")
            }

            Text(assessment.summary)
                .font(.body)
                .foregroundStyle(FrostPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(assessment.actions, id: \.self) { action in
                    Label(action, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(FrostPalette.ink.opacity(0.86))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Why")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(assessment.drivers, id: \.self) { driver in
                    Text(driver)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(assessment.level.color.opacity(0.35), lineWidth: 1)
        )
    }

    private var frostWindowText: String {
        guard let start = assessment.likelyStart, let end = assessment.likelyEnd else {
            return "No clear frost window"
        }
        return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct RiskBadge: View {
    var level: FrostRiskLevel

    var body: some View {
        Text(level.rawValue)
            .font(.caption.weight(.bold))
            .foregroundStyle(level.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(level.color.opacity(0.12), in: Capsule())
            .accessibilityLabel("Risk level \(level.rawValue)")
    }
}

private struct MetricRow: View {
    var icon: String
    var label: String
    var value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(FrostPalette.blue)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(FrostPalette.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct NotificationPermissionBanner: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        switch appModel.notifications.authorizationStatus {
        case .denied:
            Banner(
                icon: "bell.slash",
                title: "Notifications are off",
                message: "Frost warnings can only appear in the app until notifications are enabled in Settings.",
                actionTitle: nil,
                action: nil
            )
        case .notDetermined:
            Banner(
                icon: "bell.badge",
                title: "Get evening and morning frost alerts",
                message: "Local notifications are scheduled on device when risk is watch or higher.",
                actionTitle: "Allow"
            ) {
                Task { await appModel.notifications.requestPermission() }
            }
        default:
            EmptyView()
        }
    }
}

private struct Banner: View {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(FrostPalette.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(FrostPalette.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DisclaimerView: View {
    var body: some View {
        Text("Forecasts are guidance only. For high-value crops, use local sensors and professional frost systems as needed.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrostPalette.soil.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Checking overnight frost risk...")
                .font(.headline)
                .foregroundStyle(FrostPalette.ink)
        }
        .padding()
    }
}

private struct EmptyStateView: View {
    var addLocation: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 54))
                .foregroundStyle(FrostPalette.green)
            Text("Add a growing location")
                .font(.title2.weight(.semibold))
            Text("Frost Alert needs at least one garden, block, nursery, orchard, or vineyard location to assess tonight’s risk.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add location", action: addLocation)
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}

private struct ErrorStateView: View {
    var message: String
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Forecast unavailable")
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}

private struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var crop = ""
    @State private var sensitivity = SensitivityOption.sensitive
    @State private var customThreshold = 1.0

    var onSave: (String, String, PlantSensitivity) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Crop or plants", text: $crop)
                        .textInputAutocapitalization(.words)
                }

                Section("Sensitivity") {
                    Picker("Plant sensitivity", selection: $sensitivity) {
                        ForEach(SensitivityOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if sensitivity == .custom {
                        Stepper(value: $customThreshold, in: -5...8, step: 0.5) {
                            Text("Threshold: \(customThreshold.formatted(.number.precision(.fractionLength(0...1)))) C")
                        }
                    }
                }
            }
            .navigationTitle("Add location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, crop, plantSensitivity)
                        dismiss()
                    }
                }
            }
        }
    }

    private var plantSensitivity: PlantSensitivity {
        switch sensitivity {
        case .hardy: .hardy
        case .sensitive: .sensitive
        case .verySensitive: .verySensitive
        case .custom: .custom(customThreshold)
        }
    }
}

private enum SensitivityOption: String, CaseIterable, Identifiable {
    case hardy
    case sensitive
    case verySensitive
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hardy: "Hardy"
        case .sensitive: "Sensitive"
        case .verySensitive: "Very sensitive"
        case .custom: "Custom threshold"
        }
    }
}

private enum FrostPalette {
    static let background = Color(red: 0.95, green: 0.97, blue: 0.94)
    static let ink = Color(red: 0.09, green: 0.15, blue: 0.13)
    static let green = Color(red: 0.19, green: 0.45, blue: 0.28)
    static let blue = Color(red: 0.18, green: 0.42, blue: 0.56)
    static let soil = Color(red: 0.44, green: 0.34, blue: 0.22)
}

private extension FrostRiskLevel {
    var color: Color {
        switch self {
        case .safe: FrostPalette.green
        case .watch: Color(red: 0.68, green: 0.47, blue: 0.08)
        case .frostLikely: FrostPalette.blue
        case .severe: Color(red: 0.54, green: 0.13, blue: 0.16)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppModel())
}
