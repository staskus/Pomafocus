import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Colors

    private let backgroundColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.06, alpha: 1)
            : UIColor(white: 1.0, alpha: 1)
    }

    private let surfaceColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
    }

    private let accentRed = UIColor(red: 0.92, green: 0.25, blue: 0.20, alpha: 1)
    private let accentYellow = UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 1)

    private let textPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.98, alpha: 1)
            : UIColor(white: 0.08, alpha: 1)
    }

    private let textSecondary = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.65, alpha: 1)
            : UIColor(white: 0.35, alpha: 1)
    }

    // MARK: - Shield Configuration

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(
            title: "APP BLOCKED",
            subtitle: application.localizedDisplayName ?? "This app",
            icon: .init(systemName: "xmark.app.fill")
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(
            title: "APP BLOCKED",
            subtitle: application.localizedDisplayName ?? category.localizedDisplayName ?? "This app",
            icon: .init(systemName: "xmark.app.fill")
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(
            title: "WEBSITE BLOCKED",
            subtitle: webDomain.domain ?? "This website",
            icon: .init(systemName: "globe")
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(
            title: "WEBSITE BLOCKED",
            subtitle: webDomain.domain ?? category.localizedDisplayName ?? "This website",
            icon: .init(systemName: "globe")
        )
    }

    // MARK: - Configuration Builder

    private func makeConfiguration(title: String, subtitle: String, icon: UIImage?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: backgroundColor,
            icon: icon?.withTintColor(accentRed, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(
                text: title,
                color: textPrimary
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(subtitle) is blocked during focus",
                color: textSecondary
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: .white
            ),
            primaryButtonBackgroundColor: accentRed,
            secondaryButtonLabel: nil
        )
    }
}
