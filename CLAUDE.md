# Pluck - Project Context

Pluck is a macOS menu bar utility for creating customizable global hotkeys to quickly open applications.

## Architecture

### Core Components

**KeyMapping.swift**
- Maps keyboard characters to key codes for all standard keys (a-z, 0-9, punctuation, space)
- Provides display names for special characters
- Validates selector characters

**PluckKeyConfiguration (in KeyMapping.swift)**
- Represents the customizable "pluck key" (modifier combination)
- Supports Control, Option, Shift, Command in any combination
- Provides display text and validation

**HotkeyBinding (in ConfigurationManager.swift)**
- Represents a single hotkey binding: pluck key + selector character → app
- Uses private String storage for Character to support Codable
- Provides key code lookup and display text generation

**ConfigurationManager.swift**
- Manages all hotkey bindings and pluck key configuration
- Handles persistence via UserDefaults with JSON encoding
- Provides CRUD operations for bindings
- Manages double-shift activation feature toggle
- Manages Command+Tab disabling for training mode
- Default binding: Ctrl+Option+M → Messages

**HotkeyManager.swift**
- Uses CGEventTap for system-wide event interception and consumption
- Implements double-shift detection with 500ms timing window requiring complete press/release cycles
- Manages selector overlay window display and lifecycle with 5-second timeout
- Handles accessibility permissions checking with informational popup system
- Shows warning popup when permissions are missing with "Open Settings & Quit" action
- Focuses/launches applications using AppleScript and NSWorkspace fallbacks
- Maps key events to configured bindings with dynamic pluck key support
- Consumes hotkey events to prevent interference with focused applications
- Automatic timeout reset prevents stuck selector state after double-shift activation
- ESC key resets double-shift state and dismisses selector overlay
- Prevents holding shift from triggering double-shift activation
- Command+Tab blocking for training mode when enabled

**ConfigurationView.swift**
- SwiftUI interface for managing pluck key and hotkey bindings
- Real-time preview of hotkey combinations with styled display
- Double-shift activation toggle with visual previews
- Command+Tab disabling toggle in Training Mode section
- App picker integration with native file dialog
- Conflict detection for duplicate selectors
- Polished UI with consistent spacing and visual hierarchy
- Organized sections with clear labels and logical grouping
- Scrollable layout with responsive window sizing

**pluckApp.swift**
- Menu bar app entry point with custom "P" icon
- Integrates configuration window
- Manages hotkey manager lifecycle
- LSUIElement configuration hides Dock icon (menu bar only)

**SelectorOverlayView.swift**
- SwiftUI view for displaying available hotkey selectors
- Shows all configured bindings with styled key indicators and app names
- Native macOS design with material background and shadows
- Displays "Pluck" heading with clear instructions for usage

**SelectorOverlayWindow.swift**
- Borderless floating window for selector overlay display
- Auto-positioning at screen center with proper sizing
- 5-second auto-hide timer with manual hide options and timeout reset
- Non-intrusive design that doesn't steal focus or become key window
- Automatically resizes to accommodate all configured hotkey bindings

## Key Terminology

- **Pluck Key**: The modifier key combination (e.g., Ctrl+Option)
- **Selector**: The character key that follows the pluck key (e.g., 'm' for Messages)
- **Hotkey Binding**: Complete combination (e.g., Ctrl+Option+M → Messages)
- **Double-Shift**: Alternative activation method using two quick shift presses
- **Selector Overlay**: Visual popup showing available hotkey options after double-shift

## Features

- Fully customizable pluck key (any combination of Control, Option, Shift, Command)
- Character-based selectors (supports all keyboard characters: a-z, 0-9, punctuation, space)
- **Double-shift activation**: Optional alternative activation using two quick shift presses (requires complete press/release cycles)
- **Visual selector overlay**: Popup showing available hotkeys after double-shift activation
- **ESC cancellation**: ESC key resets double-shift state and dismisses overlay UI
- **Training mode**: Optional Command+Tab disabling to encourage pluck hotkey usage
- Menu bar only operation (no Dock icon) with custom "P" logo
- Custom rounded corner app icons with proper sizing and padding
- Template-based menu bar icon that adapts to system theme
- Persistent configuration storage with JSON encoding
- Real-time conflict detection and validation
- System-wide event consumption prevents interference with focused applications
- Comprehensive hotkey monitoring (works in all app contexts)
- AppleScript-based app activation with NSWorkspace fallbacks
- Accessibility permissions popup system with streamlined workflow
- Automatic System Preferences opening and app quit for permission granting
- Polished configuration UI with live preview and scrollable layout

## Technical Notes

- Uses CGEventTap for system-wide event interception and consumption
- Dual event monitoring with local NSEvent monitor as backup
- Double-shift detection uses 500ms timing window requiring complete press/release cycles (prevents holding shift from triggering)
- Requires accessibility permissions for global hotkey functionality
- App sandbox is disabled to enable global event monitoring
- Character storage uses String internally for Codable compliance
- Default pluck key: Control + Option (⌃⌥)
- Event consumption prevents hotkey interference with focused applications
- Selector overlay uses borderless NSWindow with .floating level
- LSUIElement = YES hides app from Dock, keeping only menu bar presence
- Custom MenuBarIcon.imageset with 1x/2x template rendering for theme adaptation

## Build Requirements

- macOS 15.4+
- Xcode with SwiftUI support
- Accessibility permissions for global key monitoring
- App sandbox disabled in entitlements

## Development History

### Recent Improvements
- **Command+Tab Training Mode**: Optional Command+Tab disabling to train users to use pluck hotkeys instead
- **Double-Shift Activation**: Optional alternative hotkey activation using two quick shift presses
- **Press/Release Cycle Detection**: Double-shift now requires complete key press/release cycles to prevent accidental activation from holding shift
- **ESC Key Cancellation**: ESC key resets double-shift state and dismisses selector overlay for better user control
- **Intervening Keystroke Protection**: Shift+key+shift sequences no longer trigger double-shift activation
- **Visual Selector Overlay**: Popup window displaying available hotkey options after double-shift
- **Selector Overlay Fixes**: Fixed flashing display issue and added 5-second automatic timeout
- **Complete Selector Display**: Removed 8-item limit to show all configured hotkey bindings
- **System-Wide Event Consumption**: CGEventTap implementation prevents hotkey interference with focused apps
- **Enhanced Configuration UI**: Scrollable layout with double-shift toggle and live preview updates
- **Dual Event Monitoring**: Fixed hotkeys not working in config window
- **UI Polish**: Enhanced spacing, layout, and visual hierarchy
- **Comprehensive Character Support**: Full keyboard character mapping
- **Dynamic Pluck Key**: Real-time modifier combination updates
- **Robust App Activation**: AppleScript with NSWorkspace fallbacks
- **Custom App Icons**: Rounded corner icons with ImageMagick processing and proper sizing
- **Menu Bar Only Operation**: LSUIElement configuration for clean menu bar utility behavior
- **Custom Menu Bar Icon**: Template-rendered "P" logo that adapts to system themes
- **Accessibility Permissions UX**: Informational popup when permissions missing with "Open Settings & Quit" button that opens System Preferences and terminates app for streamlined restart workflow

## Future Enhancements

- Bundle identifier detection for more reliable app targeting
- Import/export of hotkey configurations
- System app integration (e.g., System Preferences panels)
- Multiple pluck key profiles
- Global hotkey conflict detection with other apps
- Usage analytics and hotkey frequency tracking