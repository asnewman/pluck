import SwiftUI
import AppKit

struct SearchView: View {
    @State private var searchText = ""
    @State private var availableApps: [AppInfo] = []
    @State private var isLoading = true
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    let onAppSelected: (String) -> Void
    let onCancel: () -> Void
    
    private var filteredApps: [AppInfo] {
        let result: [AppInfo]
        if searchText.isEmpty {
            result = availableApps
        } else {
            result = availableApps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText)
            }
            print("SearchView: Filtered '\(searchText)' -> \(result.count) results")
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Search Apps")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.secondary)
            }
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrentApp()
                    }
                    .onChange(of: searchText) { _ in
                        selectedIndex = 0 // Reset selection when search changes
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = "" 
                        selectedIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Results
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading applications...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No applications found" : "No apps match '\(searchText)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredApps.enumerated()), id: \.element.path) { index, app in
                                AppSearchResultRow(
                                    app: app,
                                    isSelected: index == selectedIndex,
                                    onTap: {
                                        onAppSelected(app.name)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            
            // Footer hint
            if !filteredApps.isEmpty {
                Text("↑↓ to navigate • Enter to select • Esc to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .frame(width: 320, height: 400)
        .onAppear {
            loadAvailableApps()
            // Auto-focus the search field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Auto-focus when window becomes key
        }
        .background(KeyboardEventHandler { event in
            return handleKeyDown(event)
        })
    }
    
    private func loadAvailableApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppDiscovery.shared.discoverInstalledApps()
            print("SearchView: Loaded \(apps.count) apps")
            
            DispatchQueue.main.async {
                self.availableApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                print("SearchView: Available apps: \(self.availableApps.prefix(5).map(\.name))")
                self.isLoading = false
            }
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard !filteredApps.isEmpty else { return false }
        
        switch event.keyCode {
        case 125: // Down arrow
            selectedIndex = min(selectedIndex + 1, filteredApps.count - 1)
            return true
        case 126: // Up arrow
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case 36: // Return key
            selectCurrentApp()
            return true
        case 53: // Escape key
            onCancel()
            return true
        default:
            return false
        }
    }
    
    private func selectCurrentApp() {
        guard !filteredApps.isEmpty,
              selectedIndex >= 0,
              selectedIndex < filteredApps.count else {
            return
        }
        onAppSelected(filteredApps[selectedIndex].name)
    }
}

struct AppSearchResultRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
            
            // App name
            Text(app.name)
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundView)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contentShape(Rectangle())
    }
    
    private var backgroundView: some View {
        Group {
            if isSelected {
                Color.blue
            } else if isHovered {
                Color.blue.opacity(0.1)
            } else {
                Color.clear
            }
        }
    }
}

struct AppInfo {
    let name: String
    let path: String
    let icon: NSImage?
}

class AppDiscovery {
    static let shared = AppDiscovery()
    private init() {}
    
    func discoverInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        
        // Common application directories
        let appDirectories = [
            "/Applications",
            "/System/Applications", 
            "/System/Library/CoreServices",
            NSHomeDirectory() + "/Applications"
        ]
        
        print("AppDiscovery: Starting app discovery in directories: \(appDirectories)")
        
        for directory in appDirectories {
            print("AppDiscovery: Scanning directory: \(directory)")
            let foundApps = findAppsInDirectory(directory)
            print("AppDiscovery: Found \(foundApps.count) apps in \(directory)")
            if !foundApps.isEmpty {
                print("AppDiscovery: Sample apps: \(foundApps.prefix(3).map(\.name))")
            }
            apps.append(contentsOf: foundApps)
        }
        
        print("AppDiscovery: Total apps found before deduplication: \(apps.count)")
        
        // Remove duplicates based on app name
        var uniqueApps: [String: AppInfo] = [:]
        for app in apps {
            if uniqueApps[app.name] == nil {
                uniqueApps[app.name] = app
            }
        }
        
        let finalApps = Array(uniqueApps.values)
        print("AppDiscovery: Final unique apps: \(finalApps.count)")
        print("AppDiscovery: Sample final apps: \(finalApps.prefix(10).map(\.name))")
        
        // Check specifically for Spotify
        let spotifyApps = finalApps.filter { $0.name.lowercased().contains("spotify") }
        print("AppDiscovery: Spotify apps found: \(spotifyApps.map(\.name))")
        
        return finalApps
    }
    
    private func findAppsInDirectory(_ directoryPath: String) -> [AppInfo] {
        var apps: [AppInfo] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            print("AppDiscovery: Failed to read directory: \(directoryPath)")
            return apps
        }
        
        print("AppDiscovery: Directory \(directoryPath) contains \(contents.count) items")
        
        for item in contents {
            let fullPath = directoryPath + "/" + item
            
            // Check if it's an app bundle
            if item.hasSuffix(".app") {
                let appName = String(item.dropLast(4)) // Remove .app extension
                print("AppDiscovery: Found app: \(appName) at \(fullPath)")
                let icon = loadAppIcon(from: fullPath)
                
                let appInfo = AppInfo(name: appName, path: fullPath, icon: icon)
                apps.append(appInfo)
            }
        }
        
        return apps
    }
    
    private func loadAppIcon(from appPath: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        return workspace.icon(forFile: appPath)
    }
}

struct KeyboardEventHandler: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyView = nsView as? KeyHandlerView {
            keyView.onKeyDown = onKeyDown
        }
    }
}

class KeyHandlerView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return // Event was handled
        }
        super.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

#Preview {
    SearchView(
        onAppSelected: { appName in
            print("Selected: \(appName)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .padding(40)
}