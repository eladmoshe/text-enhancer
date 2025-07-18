import SwiftUI
import AppKit

struct ShortcutMenuView: View {
    let shortcuts: [ShortcutConfiguration]
    let onSelectShortcut: (ShortcutConfiguration) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Text("Select Shortcut (\(shortcuts.count) available)")
                .font(.headline)
                .padding()
            
            // Shortcuts list - using regular VStack instead of LazyVStack
            VStack(spacing: 4) {
                ForEach(0..<shortcuts.count, id: \.self) { index in
                    let shortcut = shortcuts[index]
                    Button(action: {
                        NSLog("🔧 Button clicked for: \(shortcut.name)")
                        selectShortcut(at: index)
                    }) {
                        HStack {
                            Text("\(index + 1). \(shortcut.name)")
                                .foregroundColor(.black)
                            Spacer()
                            Text(shortcut.provider.displayName)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        NSLog("🔧 Button appeared for: \(shortcut.name)")
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Footer
            Button("Close") {
                NSLog("🔧 Close button clicked")
                onDismiss()
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 400, height: 300)
        .onAppear {
            NSLog("🔧 ShortcutMenuView: Appeared with \(shortcuts.count) shortcuts")
            for (index, shortcut) in shortcuts.enumerated() {
                NSLog("🔧 ShortcutMenuView: Shortcut \(index): \(shortcut.name) - \(shortcut.provider.displayName)")
            }
        }
    }
    
    private func selectShortcut(at index: Int) {
        guard index >= 0 && index < shortcuts.count else { return }
        NSLog("🔧 ShortcutMenuView: Selected shortcut at index \(index): \(shortcuts[index].name)")
        onSelectShortcut(shortcuts[index])
    }
}

struct ShortcutMenuItemView: View {
    let shortcut: ShortcutConfiguration
    let index: Int
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Number indicator
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                // Shortcut name
                Text(shortcut.name)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Provider and model info
                HStack(spacing: 6) {
                    // Provider tag
                    let providerColor: Color = shortcut.provider == .claude ? .orange : .green
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(providerColor)
                            .frame(width: 4, height: 4)
                        Text(shortcut.provider.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(providerColor)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Model info
                    Text(formatModelName(shortcut.model))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if shortcut.effectiveIncludeScreenshot {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "camera")
                                .font(.caption2)
                            Text("Screenshot")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Prompt preview
                Text(shortcut.prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.gray.opacity(0.2) : Color.clear))
        )
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            onHover(hovering)
        }
        .onAppear {
            NSLog("🔧 ShortcutMenuItemView: Appeared for \(shortcut.name)")
        }
    }
    
    private func formatModelName(_ model: String) -> String {
        switch model {
        case "claude-3-5-sonnet-20241022": return "Sonnet"
        case "claude-opus-4-20250514": return "Opus"
        case "gpt-4o": return "4o"
        case "gpt-4o-mini": return "4o mini"
        case "gpt-4-turbo": return "4 Turbo"
        case "gpt-4": return "4"
        case "gpt-3.5-turbo": return "3.5 Turbo"
        case "o1-preview": return "o1 preview"
        case "o1-mini": return "o1 mini"
        default: return model
        }
    }
}

#Preview {
    ShortcutMenuView(
        shortcuts: [
            ShortcutConfiguration(
                id: "1",
                name: "Improve Text",
                keyCode: 18,
                modifiers: [.control, .option],
                prompt: "Improve the writing quality and clarity of this text while maintaining its original meaning and tone.",
                provider: .claude,
                model: "claude-3-5-sonnet-20241022",
                includeScreenshot: false
            ),
            ShortcutConfiguration(
                id: "2",
                name: "Fix Grammar",
                keyCode: 19,
                modifiers: [.control, .option],
                prompt: "Fix grammar and spelling errors in this text.",
                provider: .openai,
                model: "gpt-4o",
                includeScreenshot: true
            )
        ],
        onSelectShortcut: { _ in },
        onDismiss: { }
    )
    .frame(width: 600, height: 400)
}