import SwiftUI
import PomafocusKit

public struct PomodoroDashboardView: View {
    @ObservedObject private var session: PomodoroSessionController
    @Environment(\.colorScheme) private var colorScheme

    public init(session: PomodoroSessionController) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            BrutalistColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: BrutalistSpacing.lg) {
                    header
                    timerSection
                    controlsSection
                }
                .padding(BrutalistSpacing.md)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: BrutalistSpacing.xs) {
                Text("POMAFOCUS")
                    .font(BrutalistTypography.title(28))
                    .foregroundStyle(BrutalistColors.textPrimary)
                    .tracking(2)

                Text(session.displayStateText.uppercased())
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(session.isRunning ? BrutalistColors.red : BrutalistColors.textSecondary)
                    .tracking(1)
            }

            Spacer()

            if session.isRunning {
                statusBadge
            }
        }
        .padding(.top, BrutalistSpacing.sm)
    }

    private var statusBadge: some View {
        Text("ACTIVE")
            .font(BrutalistTypography.mono)
            .foregroundStyle(BrutalistColors.textInverted)
            .padding(.horizontal, BrutalistSpacing.sm)
            .padding(.vertical, BrutalistSpacing.xs)
            .background(BrutalistColors.red)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: BrutalistSpacing.lg) {
            timerDisplay
            actionButton
        }
        .padding(BrutalistSpacing.lg)
        .background(BrutalistColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.md)
                .stroke(BrutalistColors.border, lineWidth: 1)
        )
    }

    private var timerDisplay: some View {
        VStack(spacing: BrutalistSpacing.md) {
            ZStack {
                // Background track
                Circle()
                    .stroke(BrutalistColors.border, lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        session.isRunning ? BrutalistColors.red : BrutalistColors.yellow,
                        style: StrokeStyle(lineWidth: 8, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)

                // Timer text
                VStack(spacing: BrutalistSpacing.xs) {
                    Text(session.remainingDisplay)
                        .font(BrutalistTypography.timer(52))
                        .foregroundStyle(BrutalistColors.textPrimary)
                        .contentTransition(.numericText())

                    Text(session.isRunning ? "STAY FOCUSED" : "READY")
                        .font(BrutalistTypography.mono)
                        .foregroundStyle(BrutalistColors.textSecondary)
                        .tracking(2)
                }
            }
            .frame(width: 220, height: 220)

            // Minutes indicator
            HStack(spacing: BrutalistSpacing.xs) {
                Text("\(session.minutes)")
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.yellow)
                    .monospacedDigit()
                Text("MIN SESSION")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .tracking(1)
            }
        }
    }

    private var actionButton: some View {
        Button(action: session.toggleTimer) {
            VStack(spacing: BrutalistSpacing.xs) {
                Text(buttonTitle)
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.textInverted)

                if let progress = deepBreathProgress {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(BrutalistColors.yellow)
                            .frame(width: geo.size.width * progress)
                    }
                    .frame(height: 4)
                    .background(BrutalistColors.textInverted.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrutalistSpacing.md)
            .padding(.horizontal, BrutalistSpacing.lg)
            .background(session.isRunning ? BrutalistColors.red : BrutalistColors.black)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
        }
        .disabled(buttonDisabled)
        .opacity(buttonDisabled ? 0.6 : 1)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: BrutalistSpacing.md) {
            sessionLengthControl
            Divider()
                .background(BrutalistColors.border)
            PlatformBlockingPanel(isDisabled: settingsLocked)
            Divider()
                .background(BrutalistColors.border)
            deepBreathToggle
        }
        .padding(BrutalistSpacing.md)
        .background(BrutalistColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrutalistRadius.md)
                .stroke(BrutalistColors.border, lineWidth: 1)
        )
        .opacity(settingsLocked ? 0.5 : 1)
    }

    private var sessionLengthControl: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.sm) {
            HStack {
                Text("SESSION LENGTH")
                    .font(BrutalistTypography.caption)
                    .foregroundStyle(BrutalistColors.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(session.minutes) MIN")
                    .font(BrutalistTypography.headline)
                    .foregroundStyle(BrutalistColors.textPrimary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(session.minutes) },
                    set: { session.setMinutes(Int($0.rounded())) }
                ),
                in: 10...90,
                step: 1
            )
            .tint(BrutalistColors.red)
            .disabled(settingsLocked)
        }
    }

    private var deepBreathToggle: some View {
        Toggle(isOn: deepBreathBinding) {
            HStack(spacing: BrutalistSpacing.sm) {
                Image(systemName: "lungs.fill")
                    .foregroundStyle(BrutalistColors.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEEP BREATH")
                        .font(BrutalistTypography.caption)
                        .foregroundStyle(BrutalistColors.textSecondary)
                        .tracking(1)
                    Text("Pause before stopping")
                        .font(BrutalistTypography.body)
                        .foregroundStyle(BrutalistColors.textPrimary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(BrutalistColors.red)
        .disabled(settingsLocked)
    }

    // MARK: - Computed Properties

    private var progress: CGFloat {
        let total = Double(session.minutes * 60)
        guard total > 0 else { return 0 }
        return CGFloat(1 - (session.remaining / total))
    }

    private var buttonTitle: String {
        if session.isRunning {
            if session.deepBreathEnabled {
                if session.deepBreathReady {
                    return "CONFIRM STOP"
                }
                if let remaining = session.deepBreathRemaining {
                    return "BREATHE \(PomodoroSessionController.format(seconds: Int(remaining)))"
                }
            }
            return "STOP SESSION"
        }
        return "START FOCUS"
    }

    private var buttonDisabled: Bool {
        session.isRunning && session.deepBreathEnabled && session.deepBreathRemaining != nil && !session.deepBreathReady
    }

    private var deepBreathProgress: Double? {
        if let remaining = session.deepBreathRemaining {
            let elapsed = PomodoroSessionController.deepBreathDuration - remaining
            return min(max(elapsed / PomodoroSessionController.deepBreathDuration, 0), 1)
        }
        if session.deepBreathReady, let confirmation = session.deepBreathConfirmationRemaining {
            let elapsed = PomodoroSessionController.deepBreathConfirmationWindow - confirmation
            return min(max(elapsed / PomodoroSessionController.deepBreathConfirmationWindow, 0), 1)
        }
        return nil
    }

    private var deepBreathBinding: Binding<Bool> {
        Binding(
            get: { session.deepBreathEnabled },
            set: { session.setDeepBreathEnabled($0) }
        )
    }

    private var settingsLocked: Bool {
        session.isRunning
    }
}
