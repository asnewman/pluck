import SwiftUI

struct SelectorOverlayView: View {
    let hotkeyBindings: [HotkeyBinding]
    let isDoubleShiftMode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Pluck")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Press a key to open an app:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if hotkeyBindings.isEmpty {
                Text("No hotkeys configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 6) {
                    ForEach(hotkeyBindings) { binding in
                        HStack(spacing: 8) {
                            Text(KeyMapping.shared.displayName(for: binding.selectorCharacter))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(6)
                                .frame(minWidth: 28)
                            
                            Text("→")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Text(binding.appName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .frame(minWidth: 200, maxWidth: 300)
    }
}

#Preview {
    SelectorOverlayView(
        hotkeyBindings: [
            HotkeyBinding(selectorCharacter: "f", appName: "Firefox"),
            HotkeyBinding(selectorCharacter: "m", appName: "Messages"),
            HotkeyBinding(selectorCharacter: "s", appName: "Safari"),
            HotkeyBinding(selectorCharacter: "t", appName: "Terminal")
        ],
        isDoubleShiftMode: true
    )
    .padding(40)
}