import FamilyControls
import PomafocusKit
import SwiftUI

struct ScheduleDashboardView: View {
    @Bindable var store: ScheduleStore

    @State private var isPresentingEditor = false
    @State private var editingBlock: ScheduleBlock?

    var body: some View {
        ZStack {
            BrutalistColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: BrutalistSpacing.lg) {
                    header
                    scheduleCard
                }
                .padding(BrutalistSpacing.md)
            }
        }
        .sheet(isPresented: $isPresentingEditor, onDismiss: { editingBlock = nil }) {
            ScheduleBlockEditorView(block: editingBlock) { block in
                saveBlock(block)
            } onDelete: { blockID in
                deleteBlock(blockID)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: BrutalistSpacing.xs) {
                Text("SCHEDULE")
                    .font(BrutalistTypography.title(28))
                    .foregroundStyle(BrutalistColors.textPrimary)
                    .tracking(2)

                Text("AUTOMATED FOCUS BLOCKS")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .tracking(1)
            }

            Spacer()
        }
        .padding(.top, BrutalistSpacing.sm)
    }

    private var scheduleCard: some View {
        VStack(spacing: BrutalistSpacing.md) {
            if let scheduleIndex = selectedScheduleIndex {
                scheduleHeader(for: scheduleIndex)
                Divider()
                    .background(BrutalistColors.border)
                blocksList(for: scheduleIndex)
                addBlockButton
            } else {
                Text("No schedule available")
                    .font(BrutalistTypography.body)
                    .foregroundStyle(BrutalistColors.textSecondary)
            }
        }
        .padding(BrutalistSpacing.md)
        .background(BrutalistColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.md)
                .stroke(BrutalistColors.border, lineWidth: 1)
        )
    }

    private func scheduleHeader(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            Text(store.schedules[index].name)
                .font(BrutalistTypography.headline)
                .foregroundStyle(BrutalistColors.textPrimary)

            Toggle(isOn: $store.schedules[index].isEnabled) {
                Text(store.schedules[index].isEnabled ? "Schedule is live" : "Schedule is paused")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
            }
            .toggleStyle(.switch)
            .tint(BrutalistColors.red)
            .onChange(of: store.schedules[index].isEnabled) { _, _ in
                store.updateSchedule(store.schedules[index])
            }
        }
    }

    private func blocksList(for index: Int) -> some View {
        VStack(spacing: BrutalistSpacing.sm) {
            if store.schedules[index].blocks.isEmpty {
                Text("Add blocks for focus and breaks.")
                    .font(BrutalistTypography.body)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(store.schedules[index].blocks) { block in
                    Button {
                        editingBlock = block
                        isPresentingEditor = true
                    } label: {
                        ScheduleBlockRow(block: block)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addBlockButton: some View {
        Button {
            editingBlock = ScheduleBlock(
                title: "Focus Block",
                kind: .focus,
                startMinutes: 9 * 60,
                durationMinutes: 50,
                days: Set(Weekday.allCases)
            )
            isPresentingEditor = true
        } label: {
            HStack {
                Text("ADD BLOCK")
                    .font(BrutalistTypography.caption)
                    .tracking(1)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(BrutalistColors.textPrimary)
            .padding(BrutalistSpacing.sm)
            .background(BrutalistColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: BrutalistRadius.sm)
                    .stroke(BrutalistColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedScheduleIndex: Int? {
        guard let selected = store.selectedScheduleID else { return nil }
        return store.schedules.firstIndex { $0.id == selected }
    }

    private func saveBlock(_ block: ScheduleBlock) {
        guard let scheduleID = store.selectedScheduleID else { return }
        if store.schedules.first(where: { $0.id == scheduleID })?.blocks.contains(where: { $0.id == block.id }) == true {
            store.updateBlock(block, in: scheduleID)
        } else {
            store.addBlock(block, to: scheduleID)
        }
    }

    private func deleteBlock(_ blockID: UUID) {
        guard let scheduleID = store.selectedScheduleID else { return }
        store.removeBlock(blockID, from: scheduleID)
    }
}

private struct ScheduleBlockRow: View {
    let block: ScheduleBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(block.title)
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.textPrimary)
                Spacer()
                Text(block.kind.displayName.uppercased())
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(block.kind == .focus ? BrutalistColors.red : BrutalistColors.yellow)
            }

            Text("\(timeRange) • \(block.durationMinutes) min")
                .font(BrutalistTypography.mono)
                .foregroundStyle(BrutalistColors.textSecondary)

            Text(daysLabel)
                .font(BrutalistTypography.caption)
                .foregroundStyle(BrutalistColors.textSecondary)
        }
        .padding(BrutalistSpacing.sm)
        .background(BrutalistColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.sm)
                .stroke(BrutalistColors.border, lineWidth: 1)
        )
    }

    private var timeRange: String {
        let start = formatTime(minutes: block.startMinutes)
        let end = formatTime(minutes: block.endMinutes)
        return "\(start) - \(end)"
    }

    private var daysLabel: String {
        let days = block.days.isEmpty ? Weekday.allCases : Array(block.days).sorted { $0.rawValue < $1.rawValue }
        return days.map { $0.shortLabel }.joined(separator: " ")
    }

    private func formatTime(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

private struct ScheduleBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let block: ScheduleBlock?
    let onSave: (ScheduleBlock) -> Void
    let onDelete: (UUID) -> Void

    @State private var title: String
    @State private var kind: ScheduleKind
    @State private var startMinutes: Int
    @State private var durationMinutes: Int
    @State private var days: Set<Weekday>
    @State private var selection: FamilyActivitySelection
    @State private var showingPicker = false

    init(block: ScheduleBlock?, onSave: @escaping (ScheduleBlock) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.block = block
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: block?.title ?? "Focus Block")
        _kind = State(initialValue: block?.kind ?? .focus)
        _startMinutes = State(initialValue: block?.startMinutes ?? 9 * 60)
        _durationMinutes = State(initialValue: block?.durationMinutes ?? 50)
        _days = State(initialValue: block?.days ?? Set(Weekday.allCases))
        _selection = State(initialValue: block?.selection ?? FamilyActivitySelection())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Block title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    Picker("Type", selection: $kind) {
                        ForEach(ScheduleKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Start", selection: startDateBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

                    Stepper(value: $durationMinutes, in: 5...180, step: 5) {
                        Text("Duration: \(durationMinutes) min")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Days")
                            .font(.headline)
                        HStack(spacing: 6) {
                            ForEach(Weekday.allCases) { day in
                                Button {
                                    toggle(day)
                                } label: {
                                    Text(day.shortLabel)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(days.contains(day) ? BrutalistColors.black : BrutalistColors.surfaceSecondary)
                                        .foregroundStyle(days.contains(day) ? BrutalistColors.textOnColor : BrutalistColors.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if kind == .focus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blocked apps")
                                .font(.headline)
                            Text(selectionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Choose apps & websites") {
                                showingPicker = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let block {
                        Button(role: .destructive) {
                            onDelete(block.id)
                            dismiss()
                        } label: {
                            Text("Delete block")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = ScheduleBlock(
                            id: block?.id ?? UUID(),
                            title: title,
                            kind: kind,
                            startMinutes: startMinutes,
                            durationMinutes: durationMinutes,
                            days: days,
                            selection: kind == .focus ? selection : nil
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { date(from: startMinutes) },
            set: { startMinutes = minutes(from: $0) }
        )
    }

    private var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let domains = selection.webDomainTokens.count
        let categories = selection.categoryTokens.count
        if apps + domains + categories == 0 {
            return "No apps selected"
        }
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
    }

    private func toggle(_ day: Weekday) {
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
    }

    private func date(from minutes: Int) -> Date {
        let hour = minutes / 60
        let minute = minutes % 60
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }
}
