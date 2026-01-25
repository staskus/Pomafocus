import FamilyControls
import SwiftUI
import UIKit

struct ScheduleDashboardView: View {
    @Bindable var store: ScheduleStore

    @State private var isPresentingBlockEditor = false
    @State private var editingBlock: ScheduleBlock?
    @State private var isPresentingBlockListEditor = false
    @State private var editingBlockList: BlockList?
    @State private var isPresentingBulkBuilder = false
    @State private var newScheduleName = ""

    var body: some View {
        ZStack {
            BrutalistColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: BrutalistSpacing.lg) {
                    header
                    blockListCard
                    scheduleCard
                }
                .padding(BrutalistSpacing.md)
            }
        }
        .sheet(isPresented: $isPresentingBlockEditor, onDismiss: { editingBlock = nil }) {
            ScheduleBlockEditorView(
                store: store,
                block: editingBlock
            ) { block in
                saveBlock(block)
            } onDelete: { blockID in
                deleteBlock(blockID)
            }
        }
        .sheet(isPresented: $isPresentingBlockListEditor, onDismiss: { editingBlockList = nil }) {
            BlockListEditorView(
                blockList: editingBlockList,
                isDefault: editingBlockList?.id == store.defaultBlockListID
            ) { list, makeDefault in
                store.updateBlockList(list)
                if makeDefault {
                    store.setDefaultBlockList(list.id)
                }
            } onDelete: { listID in
                store.removeBlockList(listID)
            }
        }
        .sheet(isPresented: $isPresentingBulkBuilder) {
            BulkBlockBuilderView(store: store) { blocks in
                addBulkBlocks(blocks)
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

    private var blockListCard: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.md) {
            HStack {
                Text("SCREEN TIME LISTS")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .tracking(1)
                Spacer()
                Button {
                    editingBlockList = nil
                    isPresentingBlockListEditor = true
                } label: {
                    Text("ADD LIST")
                        .font(BrutalistTypography.caption)
                        .tracking(1)
                        .foregroundStyle(BrutalistColors.textOnColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(BrutalistColors.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(BrutalistColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if store.blockLists.isEmpty {
                Text("Add a screen time list to control which apps are blocked.")
                    .font(BrutalistTypography.body)
                    .foregroundStyle(BrutalistColors.textSecondary)
            } else {
                VStack(spacing: BrutalistSpacing.sm) {
                    ForEach(store.blockLists) { list in
                        Button {
                            editingBlockList = list
                            isPresentingBlockListEditor = true
                        } label: {
                            BlockListRow(
                                list: list,
                                isDefault: list.id == store.defaultBlockListID
                            ) {
                                store.setDefaultBlockList(list.id)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private var scheduleCard: some View {
        VStack(spacing: BrutalistSpacing.md) {
            if let scheduleIndex = selectedScheduleIndex {
                scheduleHeader(for: scheduleIndex)
                Divider().background(BrutalistColors.border)
                blocksList(for: scheduleIndex)
                scheduleActions
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
            HStack {
                Menu {
                    ForEach(store.schedules) { schedule in
                        Button(schedule.name) {
                            store.setSelectedSchedule(schedule.id)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.schedules[index].name)
                            .font(BrutalistTypography.headline)
                            .foregroundStyle(BrutalistColors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    newScheduleName = ""
                    showScheduleNamePrompt()
                } label: {
                    Text("ADD SCHEDULE")
                        .font(BrutalistTypography.caption)
                        .tracking(1)
                        .foregroundStyle(BrutalistColors.textOnColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(BrutalistColors.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(BrutalistColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

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

    private var scheduleActions: some View {
        VStack(spacing: BrutalistSpacing.sm) {
            Button {
                editingBlock = ScheduleBlock(
                    title: "Focus Block",
                    kind: .focus,
                    startMinutes: 9 * 60,
                    durationMinutes: 50,
                    days: Set(Weekday.allCases),
                    blockListID: store.defaultBlockListID
                )
                isPresentingBlockEditor = true
            } label: {
                actionRowLabel(
                    "ADD BLOCK",
                    systemImage: "plus",
                    background: BrutalistColors.yellow,
                    foreground: BrutalistColors.black
                )
            }
            .buttonStyle(.plain)

            Button {
                isPresentingBulkBuilder = true
            } label: {
                actionRowLabel(
                    "BULK ADD",
                    systemImage: "square.grid.2x2",
                    background: BrutalistColors.black,
                    foreground: BrutalistColors.textOnColor
                )
            }
            .buttonStyle(.plain)

            if store.schedules.count > 1 {
                Button(role: .destructive) {
                    deleteSelectedSchedule()
                } label: {
                    actionRowLabel(
                        "DELETE SCHEDULE",
                        systemImage: "trash",
                        background: BrutalistColors.surfaceSecondary,
                        foreground: BrutalistColors.red,
                        border: BrutalistColors.red
                    )
                }
                .buttonStyle(.plain)
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
                        isPresentingBlockEditor = true
                    } label: {
                        ScheduleBlockRow(
                            block: block,
                            blockListName: blockListName(for: block)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionRowLabel(
        _ text: String,
        systemImage: String,
        background: Color,
        foreground: Color,
        border: Color = BrutalistColors.border
    ) -> some View {
        HStack {
            Text(text)
                .font(BrutalistTypography.caption)
                .tracking(1)
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(foreground)
        .padding(BrutalistSpacing.sm)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.sm)
                .stroke(border, lineWidth: 1)
        )
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

    private func addBulkBlocks(_ blocks: [ScheduleBlock]) {
        guard let scheduleID = store.selectedScheduleID else { return }
        store.addBlocks(blocks, to: scheduleID)
    }

    private func deleteBlock(_ blockID: UUID) {
        guard let scheduleID = store.selectedScheduleID else { return }
        store.removeBlock(blockID, from: scheduleID)
    }

    private func deleteSelectedSchedule() {
        guard let scheduleID = store.selectedScheduleID else { return }
        store.removeSchedule(scheduleID)
    }

    private func blockListName(for block: ScheduleBlock) -> String? {
        guard block.kind == .focus else { return nil }
        if let blockID = block.blockListID,
           let list = store.blockLists.first(where: { $0.id == blockID }) {
            return list.name
        }
        return store.blockLists.first(where: { $0.id == store.defaultBlockListID })?.name
    }

    private func showScheduleNamePrompt() {
        let alert = UIAlertController(title: "New Schedule", message: "Name your schedule", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Work / Life"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = (name?.isEmpty == false) ? name! : "New Schedule"
            let schedule = store.addSchedule(named: finalName)
            store.setSelectedSchedule(schedule.id)
        })
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.rootViewController?
            .present(alert, animated: true)
    }
}

private struct BlockListRow: View {
    let list: BlockList
    let isDefault: Bool
    let onMakeDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(list.name)
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.textPrimary)
                Spacer()
                if isDefault {
                    Text("DEFAULT")
                        .font(BrutalistTypography.caption)
                        .foregroundStyle(BrutalistColors.textOnColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BrutalistColors.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Button("Make Default") {
                        onMakeDefault()
                    }
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .buttonStyle(.plain)
                }
            }

            Text(summary)
                .font(BrutalistTypography.mono)
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

    private var summary: String {
        let apps = list.selection.applicationTokens.count
        let domains = list.selection.webDomainTokens.count
        let categories = list.selection.categoryTokens.count
        if apps + domains + categories == 0 {
            return "No apps selected"
        }
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
    }
}

private struct ScheduleBlockRow: View {
    let block: ScheduleBlock
    let blockListName: String?

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

            if let blockListName {
                Text("Screen Time: \(blockListName)")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
            }
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

    let store: ScheduleStore
    let block: ScheduleBlock?
    let onSave: (ScheduleBlock) -> Void
    let onDelete: (UUID) -> Void

    @State private var title: String
    @State private var kind: ScheduleKind
    @State private var startMinutes: Int
    @State private var durationMinutes: Int
    @State private var days: Set<Weekday>
    @State private var blockListID: UUID?

    init(
        store: ScheduleStore,
        block: ScheduleBlock?,
        onSave: @escaping (ScheduleBlock) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.store = store
        self.block = block
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: block?.title ?? "Focus Block")
        _kind = State(initialValue: block?.kind ?? .focus)
        _startMinutes = State(initialValue: block?.startMinutes ?? 9 * 60)
        _durationMinutes = State(initialValue: block?.durationMinutes ?? 50)
        _days = State(initialValue: block?.days ?? Set(Weekday.allCases))
        _blockListID = State(initialValue: block?.blockListID)
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
                            Text("Screen Time list")
                                .font(.headline)
                            HStack {
                                Picker("Screen Time list", selection: $blockListID) {
                                    Text("Default").tag(UUID?.none)
                                    ForEach(store.blockLists) { list in
                                        Text(list.name).tag(Optional(list.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(BrutalistColors.textPrimary)
                                .labelsHidden()
                                Spacer()
                            }

                            if store.blockLists.isEmpty {
                                Text("No screen time lists available. Add one on the main schedule tab.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if blockListID == nil {
                                Text("Uses the global default list.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let list = store.blockLists.first(where: { $0.id == blockListID }) {
                                Text(blockListSummary(for: list.selection))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Break blocks allow everything.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                            blockListID: kind == .focus ? blockListID : nil,
                            selection: nil
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { date(from: startMinutes) },
            set: { startMinutes = minutes(from: $0) }
        )
    }

    private func toggle(_ day: Weekday) {
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
    }

    private func blockListSummary(for selection: FamilyActivitySelection) -> String {
        let apps = selection.applicationTokens.count
        let domains = selection.webDomainTokens.count
        let categories = selection.categoryTokens.count
        if apps + domains + categories == 0 {
            return "No apps selected"
        }
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
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

private struct BlockListEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let blockList: BlockList?
    let isDefault: Bool
    let onSave: (BlockList, Bool) -> Void
    let onDelete: (UUID) -> Void

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var makeDefault: Bool
    @State private var showingPicker = false

    init(
        blockList: BlockList?,
        isDefault: Bool,
        onSave: @escaping (BlockList, Bool) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.blockList = blockList
        self.isDefault = isDefault
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: blockList?.name ?? "New Screen Time List")
        _selection = State(initialValue: blockList?.selection ?? FamilyActivitySelection())
        _makeDefault = State(initialValue: isDefault)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("List name", text: $name)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Blocked apps")
                        .font(.headline)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showingPicker = true
                    } label: {
                        HStack {
                            Text("CHOOSE APPS")
                                .font(BrutalistTypography.caption)
                                .tracking(1)
                            Spacer()
                            Image(systemName: "chevron.right")
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

                Toggle("Set as default", isOn: $makeDefault)
                    .toggleStyle(.switch)

                Spacer()

                if let blockList {
                    Button(role: .destructive) {
                        onDelete(blockList.id)
                        dismiss()
                    } label: {
                        Text("Delete list")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Screen Time List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = BlockList(
                            id: blockList?.id ?? UUID(),
                            name: name.isEmpty ? "Screen Time List" : name,
                            selection: selection
                        )
                        onSave(updated, makeDefault)
                        dismiss()
                    }
                }
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
    }

    private var summary: String {
        let apps = selection.applicationTokens.count
        let domains = selection.webDomainTokens.count
        let categories = selection.categoryTokens.count
        if apps + domains + categories == 0 {
            return "No apps selected"
        }
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
    }
}

private struct BulkBlockBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let store: ScheduleStore
    let onGenerate: ([ScheduleBlock]) -> Void

    @State private var startMinutes: Int = 6 * 60
    @State private var endMinutes: Int = 18 * 60
    @State private var focusMinutes: Int = 50
    @State private var breakMinutes: Int = 10
    @State private var focusTitle: String = "Focus"
    @State private var breakTitle: String = "Break"
    @State private var days: Set<Weekday> = Set(Weekday.allCases)
    @State private var blockListID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Start", selection: startBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                    DatePicker("End", selection: endBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

                    Stepper(value: $focusMinutes, in: 5...180, step: 5) {
                        Text("Focus: \(focusMinutes) min")
                    }

                    Stepper(value: $breakMinutes, in: 5...60, step: 5) {
                        Text("Break: \(breakMinutes) min")
                    }

                    TextField("Focus title", text: $focusTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Break title", text: $breakTitle)
                        .textFieldStyle(.roundedBorder)

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Time list")
                            .font(.headline)
                        HStack {
                            Picker("Screen Time list", selection: $blockListID) {
                                Text("Default").tag(UUID?.none)
                                ForEach(store.blockLists) { list in
                                    Text(list.name).tag(Optional(list.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(BrutalistColors.textPrimary)
                            .labelsHidden()
                            Spacer()
                        }
                    }

                    Text("Creates alternating focus and break blocks between the start and end time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Bulk Blocks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let blocks = buildBlocks()
                        onGenerate(blocks)
                        dismiss()
                    }
                }
            }
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { date(from: startMinutes) },
            set: { startMinutes = minutes(from: $0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { date(from: endMinutes) },
            set: { endMinutes = minutes(from: $0) }
        )
    }

    private func toggle(_ day: Weekday) {
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
    }

    private func buildBlocks() -> [ScheduleBlock] {
        guard endMinutes > startMinutes else { return [] }
        var blocks: [ScheduleBlock] = []
        var cursor = startMinutes
        var isFocus = true
        while cursor < endMinutes {
            let duration = isFocus ? focusMinutes : breakMinutes
            if duration <= 0 { break }
            let remaining = endMinutes - cursor
            if remaining <= 0 { break }
            let finalDuration = min(duration, remaining)
            let title = isFocus ? focusTitle : breakTitle
            let kind: ScheduleKind = isFocus ? .focus : .break
            let block = ScheduleBlock(
                title: title.isEmpty ? (isFocus ? "Focus" : "Break") : title,
                kind: kind,
                startMinutes: cursor,
                durationMinutes: finalDuration,
                days: days,
                blockListID: isFocus ? blockListID : nil,
                selection: nil
            )
            blocks.append(block)
            cursor += finalDuration
            isFocus.toggle()
        }
        return blocks
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
