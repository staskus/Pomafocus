import SwiftUI
import PomafocusKit

@MainActor
struct PlatformBlockingPanel: View {
    @StateObject private var blocker: PomodoroBlocker
    @State private var showingScreenTime = false
    private let isDisabled: Bool

    init(blocker: PomodoroBlocker? = nil, isDisabled: Bool = false) {
        _blocker = StateObject(wrappedValue: blocker ?? PomodoroBlocker.shared)
        self.isDisabled = isDisabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            HStack(spacing: BrutalistSpacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(BrutalistColors.yellow)
                    .font(.system(size: 16, weight: .bold))

                Text("SCREEN TIME")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .tracking(1)
            }

            Text(blockingSummary)
                .font(BrutalistTypography.mono)
                .foregroundStyle(blocker.hasSelection ? BrutalistColors.textPrimary : BrutalistColors.textSecondary)

            Button {
                showingScreenTime = true
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
            .disabled(isDisabled)
        }
        .sheet(isPresented: $showingScreenTime) {
            ScreenTimeSettingsView()
        }
        .allowsHitTesting(!isDisabled)
    }

    private var blockingSummary: String {
        blocker.hasSelection ? blocker.selectionSummary : "No apps selected"
    }
}
