# Context

## Brutalist Design System Implementation

### Summary
Redesigned the iOS app with a brutalist aesthetic using a grey/red/white/black/yellow color scheme inspired by the app icon.

### Changes Made

1. **BrutalistTheme.swift** (`apps/shared/Sources/`)
   - Color system with light/dark mode support
   - Typography system using system fonts with heavy weights
   - Spacing and radius constants
   - Reusable button styles and view modifiers

2. **Color Assets Updated**
   - `AccentDeep`: Black (light mode) / Near-black (dark mode)
   - `AccentBright`: Tomato red with light/dark variants
   - `AccentGlow`: Yellow with light/dark variants
   - New: `BrutalistSurface` - grey surface colors
   - New: `BrutalistBorder` - border colors

3. **PomodoroDashboardView.swift** (`apps/shared/Sources/`)
   - Bold uppercase typography with letter spacing
   - Solid background colors instead of gradients
   - Sharp card design with 1px borders
   - Timer ring with 8pt stroke, butt linecap
   - Red/black action buttons based on state
   - "ACTIVE" status badge when timer running

4. **PomodoroBlockingPanel.swift** (`apps/shared/Sources/`)
   - Consistent brutalist styling
   - Yellow shield icon accent
   - Secondary button style for navigation

5. **PomafocusActivities.swift** (`apps/ios/Widgets/`)
   - Monospaced heavy font for timer
   - Rectangle progress bar instead of rounded
   - "ACTIVE" badge with yellow background
   - Dark background with high contrast text

### Design Principles Applied
- Raw, honest materials (solid colors, no gradients)
- Bold, heavy typography (black/heavy weights)
- Strong contrast (black/white with red/yellow accents)
- Minimal corner radius (4-8px max)
- Function over form
- Exposed structure (visible borders)
