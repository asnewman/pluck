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
- Registers global event monitor for key combinations
- Handles accessibility permissions checking
- Focuses/launches applications using AppleScript and NSWorkspace
- Maps key events to configured bindings

**ConfigurationView.swift**
- SwiftUI interface for managing pluck key and hotkey bindings
- Real-time preview of hotkey combinations
- App picker integration
- Conflict detection for duplicate selectors

**pluckApp.swift**
- Menu bar app entry point
- Integrates configuration window
- Manages hotkey manager lifecycle

## Key Terminology

- **Pluck Key**: The modifier key combination (e.g., Ctrl+Option)
- **Selector**: The character key that follows the pluck key (e.g., 'm' for Messages)
- **Hotkey Binding**: Complete combination (e.g., Ctrl+Option+M → Messages)

## Features

- Fully customizable pluck key (any combination of modifiers)
- Character-based selectors (supports all keyboard characters)
- Menu bar integration with native macOS styling
- Persistent configuration storage
- Real-time conflict detection
- AppleScript-based app activation for reliability
- Accessibility permissions handling

## Technical Notes

- Uses NSEvent.addGlobalMonitorForEvents for key monitoring
- Requires accessibility permissions for global hotkey functionality
- App sandbox is disabled to enable global event monitoring
- Character storage uses String internally for Codable compliance
- Default pluck key: Control + Option (⌃⌥)

## Build Requirements

- macOS 15.4+
- Xcode with SwiftUI support
- Accessibility permissions for global key monitoring
- App sandbox disabled in entitlements

## Future Enhancements

- Bundle identifier detection for more reliable app targeting
- Import/export of hotkey configurations
- System app integration (e.g., System Preferences panels)
- Multiple pluck key profiles