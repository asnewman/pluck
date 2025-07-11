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
- Default binding: Ctrl+Option+M → Messages

**HotkeyManager.swift**
- Uses CGEventTap for system-wide event interception and consumption
- Implements double-shift detection with 500ms timing window
- Manages selector overlay window display and lifecycle
- Handles accessibility permissions checking with informational popup system
- Shows warning popup when permissions are missing with "Open Settings & Quit" action
- Focuses/launches applications using AppleScript and NSWorkspace fallbacks
- Maps key events to configured bindings with dynamic pluck key support
- Consumes hotkey events to prevent interference with focused applications

**ConfigurationView.swift**
- SwiftUI interface for managing pluck key and hotkey bindings
- Real-time preview of hotkey combinations with styled display
- Double-shift activation toggle with visual previews
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
- Shows up to 8 bindings with styled key indicators and app names
- Native macOS design with material background and shadows
- Supports both pluck key and double-shift activation modes

**SelectorOverlayWindow.swift**
- Borderless floating window for selector overlay display
- Auto-positioning at screen center with proper sizing
- 5-second auto-hide timer with manual hide options
- Non-intrusive design that doesn't steal focus or become key window

## Key Terminology

- **Pluck Key**: The modifier key combination (e.g., Ctrl+Option)
- **Selector**: The character key that follows the pluck key (e.g., 'm' for Messages)
- **Hotkey Binding**: Complete combination (e.g., Ctrl+Option+M → Messages)
- **Double-Shift**: Alternative activation method using two quick shift presses
- **Selector Overlay**: Visual popup showing available hotkey options after double-shift

## Features

- Fully customizable pluck key (any combination of Control, Option, Shift, Command)
- Character-based selectors (supports all keyboard characters: a-z, 0-9, punctuation, space)
- **Double-shift activation**: Optional alternative activation using two quick shift presses
- **Visual selector overlay**: Popup showing available hotkeys after double-shift activation
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
- Double-shift detection uses 500ms timing window for rapid successive presses
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
- **Double-Shift Activation**: Optional alternative hotkey activation using two quick shift presses
- **Visual Selector Overlay**: Popup window displaying available hotkey options after double-shift
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