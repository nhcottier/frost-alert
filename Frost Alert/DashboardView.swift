import SwiftUI
import UIKit
import UserNotifications
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddLocation = false
    @State private var editingLocation: GrowingLocation?
    @State private var deletingLocation: GrowingLocation?
    @State private var collapsedLocationIDs: Set<UUID> = []
    @State private var didApplyInitialCollapse = false
    @State private var isReordering = false
    @State private var draggingLocationID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                FrostPalette.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Frost Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if canReorderLocations {
                        Button(isReordering ? "Done" : "Reorder") {
                            withAnimation(.snappy) {
                                isReordering.toggle()
                                if isReordering {
                                    collapsedLocationIDs = Set(appModel.locations.map(\.id))
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    HeaderBrandView()
                }
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await appModel.refreshNotificationPermission() }
            }
            .sheet(isPresented: $showingAddLocation) {
                LocationEditorView { name, crop, sensitivity, result in
                    appModel.addLocation(name: name, crop: crop, sensitivity: sensitivity, searchResult: result)
                    Task { await appModel.load() }
                }
            }
            .sheet(item: $editingLocation) { location in
                LocationEditorView(location: location) { name, crop, sensitivity, result in
                    appModel.updateLocation(id: location.id, name: name, crop: crop, sensitivity: sensitivity, searchResult: result)
                    Task { await appModel.load() }
                }
            }
            .alert("Delete location?", isPresented: deleteConfirmationBinding, presenting: deletingLocation) { location in
                Button("Delete", role: .destructive) {
                    appModel.deleteLocation(id: location.id)
                    collapsedLocationIDs.remove(location.id)
                    if appModel.locations.count < 2 {
                        isReordering = false
                    }
                    Task { await appModel.load() }
                }
                Button("Cancel", role: .cancel) {}
            } message: { location in
                Text("This removes \(location.name) and its scheduled frost alerts.")
            }
        }
    }

    private var canReorderLocations: Bool {
        if case .loaded(let assessments) = appModel.state {
            return assessments.count > 1
        }
        return false
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { deletingLocation != nil },
            set: { isPresented in
                if !isPresented {
                    deletingLocation = nil
                }
            }
        )
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
                VStack(alignment: .leading, spacing: 16) {
                    NotificationPermissionBanner()
                    DashboardHeader(assessments: assessments)
                    ForEach(assessments) { assessment in
                        reorderableLocationCard(assessment)
                    }
                    DisclaimerView()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .onAppear {
                collapseLoadedLocationsIfNeeded(assessments)
            }
        }
    }

    private func collapseLoadedLocationsIfNeeded(_ assessments: [LocationAssessment]) {
        guard !didApplyInitialCollapse else { return }
        collapsedLocationIDs = Set(assessments.map(\.location.id))
        didApplyInitialCollapse = true
    }

    private func toggleCollapsedLocation(_ id: UUID) {
        withAnimation(.snappy) {
            if collapsedLocationIDs.contains(id) {
                collapsedLocationIDs.remove(id)
            } else {
                collapsedLocationIDs.insert(id)
            }
        }
    }

    @ViewBuilder
    private func reorderableLocationCard(_ assessment: LocationAssessment) -> some View {
        let card = LocationRiskCard(
            locationAssessment: assessment,
            isCollapsed: isReordering || collapsedLocationIDs.contains(assessment.location.id),
            isReordering: isReordering,
            toggleCollapse: {
                toggleCollapsedLocation(assessment.location.id)
            },
            edit: { editingLocation = assessment.location },
            delete: { deletingLocation = assessment.location }
        )

        if isReordering {
            card
                .opacity(draggingLocationID == assessment.location.id ? 0.45 : 1)
                .onDrag {
                    draggingLocationID = assessment.location.id
                    return NSItemProvider(object: assessment.location.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: LocationReorderDropDelegate(
                        targetID: assessment.location.id,
                        draggingLocationID: $draggingLocationID,
                        moveLocation: { draggedID, targetID in
                            appModel.moveLocation(id: draggedID, toTarget: targetID)
                        }
                    )
                )
        } else {
            card
        }
    }
}

private struct HeaderBrandView: View {
    var body: some View {
        HStack(spacing: 8) {
            FrostMark(size: 28)
            Text("Frost Alert")
                .font(.headline.weight(.semibold))
                .foregroundStyle(FrostPalette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Frost Alert")
    }
}

private struct FrostMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.73, green: 0.88, blue: 1), FrostPalette.blue.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "snowflake")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: FrostPalette.blue.opacity(0.35), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: FrostPalette.blue.opacity(0.18), radius: 5, x: 0, y: 2)
        .accessibilityHidden(true)
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
                .foregroundStyle(FrostPalette.secondaryText)
            Text(highestRisk.rawValue)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(highestRisk.color)
                .minimumScaleFactor(0.8)
            Text("Focused frost guidance for growing locations, not a full weather dashboard.")
                .font(.callout)
                .foregroundStyle(FrostPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}

private struct LocationRiskCard: View {
    var locationAssessment: LocationAssessment
    var isCollapsed: Bool
    var isReordering: Bool
    var toggleCollapse: () -> Void
    var edit: () -> Void
    var delete: () -> Void

    private var assessment: FrostRiskAssessment { locationAssessment.assessment }
    private var location: GrowingLocation { locationAssessment.location }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: toggleCollapse) {
                    Image(systemName: isCollapsed ? "chevron.right.circle" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundStyle(FrostPalette.blue)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(isCollapsed ? "Expand \(location.name)" : "Collapse \(location.name)")
                .disabled(isReordering)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FrostPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .layoutPriority(1)
                    Text("\(location.crop) - \(location.sensitivity.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isCollapsed {
                        Text(collapsedDetailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isReordering else { return }
                    toggleCollapse()
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    RiskBadge(level: assessment.level)
                    if isReordering {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .accessibilityLabel("Drag \(location.name) to reorder")
                    } else {
                        Menu {
                            Button {
                                edit()
                            } label: {
                                Label("Edit location", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                delete()
                            } label: {
                                Label("Delete location", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Location options")
                    }
                }
            }

            if !isCollapsed {
                VStack(alignment: .leading, spacing: 10) {
                    MetricRow(icon: "thermometer.low", label: "Expected low", value: expectedLowText)
                    MetricRow(icon: "clock", label: "Frost forecast period", value: frostPeriodText)
                    MetricRow(icon: "slider.horizontal.3", label: "Plant threshold", value: "\(location.sensitivity.thresholdCelsius.formatted(.number.precision(.fractionLength(0...1)))) C")
                }

                ThreeDayOutlookView(outlook: locationAssessment.outlook)

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
        }
        .padding(16)
        .background(FrostPalette.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(assessment.level.cardStroke, lineWidth: 1)
        )
        .shadow(color: FrostPalette.shadow, radius: 10, x: 0, y: 5)
    }

    private var expectedLowText: String {
        guard assessment.hasForecastData else { return "Unavailable" }
        return "\(assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))) C"
    }

    private var collapsedDetailText: String {
        guard assessment.hasForecastData else { return "Low unavailable | Frost: None" }
        return "Low \(assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))) C | Frost: \(frostPeriodText)"
    }

    private var frostPeriodText: String {
        guard let start = assessment.likelyStart, let end = assessment.likelyEnd else {
            return "None"
        }
        return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct LocationReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingLocationID: UUID?
    let moveLocation: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingLocationID, draggingLocationID != targetID else { return }
        withAnimation(.snappy) {
            moveLocation(draggingLocationID, targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingLocationID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        guard !info.hasItemsConforming(to: [UTType.text]) else { return }
        draggingLocationID = nil
    }
}

private struct ThreeDayOutlookView: View {
    var outlook: [ScheduledLocationAssessment]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("3-day frost outlook")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(outlook.prefix(3)) { assessment in
                    OutlookRow(assessment: assessment)
                }
            }
        }
        .padding(12)
        .background(FrostPalette.panel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct OutlookRow: View {
    var assessment: ScheduledLocationAssessment

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nightLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrostPalette.ink)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(assessment.assessment.level.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(assessment.assessment.level.color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var nightLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(assessment.nightStart) {
            return "Tonight"
        }
        if calendar.isDateInTomorrow(assessment.nightStart) {
            return "Tomorrow night"
        }
        return assessment.nightStart.formatted(.dateTime.weekday(.wide)) + " night"
    }

    private var detailText: String {
        guard assessment.assessment.hasForecastData else {
            return "Low unavailable | Frost: None"
        }
        let low = assessment.assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))
        return "Low \(low) C | Frost: \(frostPeriodText)"
    }

    private var frostPeriodText: String {
        guard let start = assessment.assessment.likelyStart, let end = assessment.assessment.likelyEnd else {
            return "None"
        }
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
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
            .background(level.badgeBackground, in: Capsule())
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
                .foregroundStyle(FrostPalette.accent)
            Text(label)
                .foregroundStyle(FrostPalette.secondaryText)
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
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch appModel.notifications.authorizationStatus {
        case .denied:
            Banner(
                icon: "bell.slash",
                title: "Frost alerts need notifications",
                message: "Enable notifications so evening and morning warnings can reach you in time.",
                actionTitle: "Allow"
            ) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settingsURL)
                }
            }
        case .notDetermined:
            Banner(
                icon: "bell.badge",
                title: "Get evening and morning frost alerts",
                message: "Local notifications are scheduled on device when risk is watch or higher.",
                actionTitle: "Allow"
            ) {
                Task { await appModel.requestNotificationPermission() }
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
                .foregroundStyle(FrostPalette.accent)
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
        .background(FrostPalette.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(FrostPalette.separator, lineWidth: 1)
        )
    }
}

private struct DisclaimerView: View {
    var body: some View {
        Text("Forecasts are guidance only. For high-value crops, use local sensors and professional frost systems as needed.")
            .font(.footnote)
            .foregroundStyle(FrostPalette.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrostPalette.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FrostPalette.separator, lineWidth: 1)
            )
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
                .foregroundStyle(FrostPalette.safe)
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

private struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var currentLocationService = CurrentLocationService()
    @State private var name = ""
    @State private var locationQuery = ""
    @State private var crop = ""
    @State private var sensitivity = SensitivityOption.sensitive
    @State private var customThreshold = 1.0
    @State private var searchResults: [LocationSearchResult] = []
    @State private var selectedResult: LocationSearchResult?
    @State private var isSearching = false
    @State private var isUsingCurrentLocation = false
    @State private var errorMessage: String?

    private let searchService = LocationSearchService()
    private let location: GrowingLocation?

    var onSave: (String, String, PlantSensitivity, LocationSearchResult) -> Void

    init(location: GrowingLocation? = nil, onSave: @escaping (String, String, PlantSensitivity, LocationSearchResult) -> Void) {
        self.location = location
        self.onSave = onSave
        let initialSensitivity = SensitivityOption(sensitivity: location?.sensitivity ?? .sensitive)
        _name = State(initialValue: location?.name ?? "")
        _locationQuery = State(initialValue: location?.subtitle ?? "")
        _crop = State(initialValue: location?.crop == "Sensitive plants" ? "" : location?.crop ?? "")
        _sensitivity = State(initialValue: initialSensitivity)
        _customThreshold = State(initialValue: location?.sensitivity.thresholdCelsius ?? PlantSensitivity.sensitive.thresholdCelsius)
        _selectedResult = State(initialValue: location.flatMap(Self.searchResult))
        _searchResults = State(initialValue: location.flatMap { [Self.searchResult(for: $0)].compactMap { $0 } } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Growing area name", text: $name)
                        .textInputAutocapitalization(.words)

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        if isUsingCurrentLocation {
                            Label("Finding current location", systemImage: "location")
                        } else {
                            Label("Use current location", systemImage: "location.fill")
                        }
                    }
                    .disabled(isSearching || isUsingCurrentLocation)

                    TextField("Town, address, vineyard, or orchard", text: $locationQuery)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await search() }
                        }
                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching {
                            Label("Searching", systemImage: "magnifyingglass")
                        } else {
                            Label("Find location", systemImage: "location.magnifyingglass")
                        }
                    }
                    .disabled(isSearching)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    ForEach(searchResults) { result in
                        Button {
                            selectedResult = result
                            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                name = result.name
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedResult == result ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedResult == result ? FrostPalette.accent : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name)
                                        .foregroundStyle(FrostPalette.ink)
                                    Text(result.subtitle.isEmpty ? "Matched location" : result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Plants") {
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
            .navigationTitle(location == nil ? "Add location" : "Edit location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let selectedResult {
                            onSave(name, crop, plantSensitivity, selectedResult)
                            dismiss()
                        }
                    }
                    .disabled(selectedResult == nil)
                }
            }
        }
    }

    private func search() async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let results = try await searchService.search(locationQuery)
            searchResults = results
            selectedResult = results.first
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let first = results.first {
                name = first.name
            }
        } catch {
            searchResults = []
            selectedResult = nil
            errorMessage = error.localizedDescription
        }
    }

    private func useCurrentLocation() async {
        isUsingCurrentLocation = true
        errorMessage = nil
        defer { isUsingCurrentLocation = false }

        do {
            let location = try await currentLocationService.currentLocation()
            let result = try await searchService.result(for: location)
            searchResults = [result]
            selectedResult = result
            locationQuery = result.subtitle
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = result.name
            }
        } catch {
            searchResults = []
            selectedResult = nil
            errorMessage = error.localizedDescription
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

    private static func searchResult(for location: GrowingLocation) -> LocationSearchResult? {
        guard let coordinate = location.coordinate else { return nil }
        return LocationSearchResult(
            name: location.name,
            subtitle: location.subtitle,
            coordinate: coordinate
        )
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

    init(sensitivity: PlantSensitivity) {
        switch sensitivity {
        case .hardy: self = .hardy
        case .sensitive: self = .sensitive
        case .verySensitive: self = .verySensitive
        case .custom: self = .custom
        }
    }
}

private enum FrostPalette {
    static let background = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let panel = Color(red: 0.96, green: 0.98, blue: 1.0)
    static let separator = Color(uiColor: .separator).opacity(0.22)
    static let shadow = Color(red: 0.04, green: 0.12, blue: 0.24).opacity(0.08)
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.20)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let safe = Color(red: 0.15, green: 0.47, blue: 0.30)
    static let accent = Color(red: 0.06, green: 0.35, blue: 0.67)
    static let frost = Color(red: 0.02, green: 0.27, blue: 0.66)
    static let severe = Color(red: 0.01, green: 0.16, blue: 0.42)
    static let watch = Color(red: 0.62, green: 0.42, blue: 0.07)
    static let blue = accent
}

private extension FrostRiskLevel {
    var color: Color {
        switch self {
        case .safe: FrostPalette.safe
        case .watch: FrostPalette.watch
        case .frostLikely: FrostPalette.frost
        case .severe: FrostPalette.severe
        }
    }

    var badgeBackground: Color {
        switch self {
        case .safe:
            return FrostPalette.safe.opacity(0.12)
        case .watch:
            return FrostPalette.watch.opacity(0.14)
        case .frostLikely:
            return FrostPalette.frost.opacity(0.12)
        case .severe:
            return FrostPalette.severe.opacity(0.12)
        }
    }

    var cardStroke: Color {
        switch self {
        case .safe:
            return FrostPalette.separator
        case .watch:
            return FrostPalette.watch.opacity(0.24)
        case .frostLikely:
            return FrostPalette.frost.opacity(0.24)
        case .severe:
            return FrostPalette.severe.opacity(0.28)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppModel())
}
