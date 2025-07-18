import SwiftUI
import AppKit

struct ShortcutMenuView: View {
    let shortcuts: [ShortcutConfiguration]
    let onSelectShortcut: (ShortcutConfiguration) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Shortcut")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close menu (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Shortcuts list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                        ShortcutMenuItemView(
                            shortcut: shortcut,
                            index: index,
                            isSelected: index == selectedIndex,
                            isHovered: index == hoveredIndex,
                            onTap: {
                                selectShortcut(at: index)
                            },
                            onHover: { isHovering in
                                hoveredIndex = isHovering ? index : nil
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
            
            // Footer with instructions
            HStack {
                Text("↑↓ Navigate • Enter Select • Esc Close • 1-9 Quick Select")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(width: 500)
        .onAppear {
            // Focus will be handled by the window controller
        }
    }
    
    private func selectShortcut(at index: Int) {
        guard index >= 0 && index < shortcuts.count else { return }
        onSelectShortcut(shortcuts[index])
    }
    
    func handleKeyEvent(_ event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            selectedIndex = min(selectedIndex + 1, shortcuts.count - 1)
        case 126: // Up arrow
            selectedIndex = max(selectedIndex - 1, 0)
        case 36: // Enter
            selectShortcut(at: selectedIndex)
        case 53: // Escape
            onDismiss()
        default:
            // Handle number keys 1-9 for quick selection
            if let numberKey = getNumberFromKeyCode(event.keyCode),
               numberKey > 0 && numberKey <= shortcuts.count {
                selectShortcut(at: numberKey - 1)
            }
        }
    }
    
    private func getNumberFromKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 22: return 5
        case 23: return 6
        case 24: return 7
        case 25: return 8
        case 26: return 9
        default: return nil
        }
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