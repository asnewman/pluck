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
- Default binding: Ctrl+Option+M → Messages

**HotkeyManager.swift**
- Registers both global and local event monitors for comprehensive coverage
- Global monitor: captures hotkeys when other apps are focused
- Local monitor: captures hotkeys when own app/config window is focused
- Handles accessibility permissions checking with user guidance
- Focuses/launches applications using AppleScript and NSWorkspace fallbacks
- Maps key events to configured bindings with dynamic pluck key support

**ConfigurationView.swift**
- SwiftUI interface for managing pluck key and hotkey bindings
- Real-time preview of hotkey combinations with styled display
- App picker integration with native file dialog
- Conflict detection for duplicate selectors
- Polished UI with consistent spacing and visual hierarchy
- Organized sections with clear labels and logical grouping

**pluckApp.swift**
- Menu bar app entry point with custom "P" icon
- Integrates configuration window
- Manages hotkey manager lifecycle
- LSUIElement configuration hides Dock icon (menu bar only)

## Key Terminology

- **Pluck Key**: The modifier key combination (e.g., Ctrl+Option)
- **Selector**: The character key that follows the pluck key (e.g., 'm' for Messages)
- **Hotkey Binding**: Complete combination (e.g., Ctrl+Option+M → Messages)

## Features

- Fully customizable pluck key (any combination of Control, Option, Shift, Command)
- Character-based selectors (supports all keyboard characters: a-z, 0-9, punctuation, space)
- Menu bar only operation (no Dock icon) with custom "P" logo
- Custom rounded corner app icons with proper sizing and padding
- Template-based menu bar icon that adapts to system theme
- Persistent configuration storage with JSON encoding
- Real-time conflict detection and validation
- Comprehensive hotkey monitoring (works in all app contexts)
- AppleScript-based app activation with NSWorkspace fallbacks
- Accessibility permissions handling with user guidance
- Polished configuration UI with live preview

## Technical Notes

- Uses dual event monitoring: NSEvent.addGlobalMonitorForEvents + addLocalMonitorForEvents
- Global monitor captures events when other apps are focused
- Local monitor captures events when own app/config window is focused
- Requires accessibility permissions for global hotkey functionality
- App sandbox is disabled to enable global event monitoring
- Character storage uses String internally for Codable compliance
- Default pluck key: Control + Option (⌃⌥)
- Event consumption prevents UI interference in local monitoring
- LSUIElement = YES hides app from Dock, keeping only menu bar presence
- Custom MenuBarIcon.imageset with 1x/2x template rendering for theme adaptation

## Build Requirements

- macOS 15.4+
- Xcode with SwiftUI support
- Accessibility permissions for global key monitoring
- App sandbox disabled in entitlements

## Development History

### Recent Improvements
- **Dual Event Monitoring**: Fixed hotkeys not working in config window
- **UI Polish**: Enhanced spacing, layout, and visual hierarchy
- **Comprehensive Character Support**: Full keyboard character mapping
- **Dynamic Pluck Key**: Real-time modifier combination updates
- **Robust App Activation**: AppleScript with NSWorkspace fallbacks
- **Custom App Icons**: Rounded corner icons with ImageMagick processing and proper sizing
- **Menu Bar Only Operation**: LSUIElement configuration for clean menu bar utility behavior
- **Custom Menu Bar Icon**: Template-rendered "P" logo that adapts to system themes

## Future Enhancements

- Bundle identifier detection for more reliable app targeting
- Import/export of hotkey configurations
- System app integration (e.g., System Preferences panels)
- Multiple pluck key profiles
- Global hotkey conflict detection with other apps
- Usage analytics and hotkey frequency tracking