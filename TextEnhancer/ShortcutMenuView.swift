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
                Text("Quick Launch")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(shortcuts.count) shortcuts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            // Shortcuts list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(0..<shortcuts.count, id: \.self) { index in
                        rowView(for: index)
                    }
                }
                .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 500, height: 400)
        .onAppear {
            NSLog("🔧 ShortcutMenuView: Appeared with \(shortcuts.count) shortcuts")
            for (index, shortcut) in shortcuts.enumerated() {
                NSLog("🔧 ShortcutMenuView: Shortcut \(index): \(shortcut.name) - \(shortcut.provider.displayName)")
            }
        }
        .background(
            // Invisible view to capture key events
            KeyEventHandlerView { keyEvent in
                if keyEvent.keyCode == 53 { // Escape key
                    NSLog("🔧 ShortcutMenuView: Escape key pressed")
                    onDismiss()
                    return true
                }
                return false
            }
        )
    }
    
    private func selectShortcut(at index: Int) {
        guard index >= 0 && index < shortcuts.count else { return }
        NSLog("🔧 ShortcutMenuView: Selected shortcut at index \(index): \(shortcuts[index].name)")
        onSelectShortcut(shortcuts[index])
    }

    // MARK: - Row View

    @ViewBuilder
    private func rowView(for index: Int) -> some View {
        let shortcut = shortcuts[index]

        ShortcutMenuItemView(
            shortcut: shortcut,
            index: index,
            isSelected: hoveredIndex == index,
            isHovered: hoveredIndex == index,
            onTap: {
                NSLog("🔧 Row tapped for: \(shortcut.name)")
                selectShortcut(at: index)
            },
            onHover: { hovering in
                hoveredIndex = hovering ? index : nil
            }
        )
        .animation(.easeInOut(duration: 0.15), value: hoveredIndex)
    }
    
    @ViewBuilder
    private func providerTagView(for shortcut: ShortcutConfiguration) -> some View {
        let providerTextColor: Color = {
            switch shortcut.provider {
            case .claude:
                return .orange
            case .openai:
                return .black
            }
        }()
        
        let providerBackgroundColor: Color = {
            switch shortcut.provider {
            case .claude:
                return Color.orange.opacity(0.1)
            case .openai:
                return Color.white
            }
        }()
        
        HStack(spacing: 4) {
            Circle()
                .fill(providerTextColor)
                .frame(width: 6, height: 6)
            Text(shortcut.provider.displayName)
                .font(.caption)
                .fontWeight(.medium)
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatModelName(shortcut.model))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(providerBackgroundColor)
        .foregroundColor(providerTextColor)
        .cornerRadius(10)
        .overlay(
            Group {
                if shortcut.provider == .openai {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                }
            }
        )
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

struct KeyEventHandlerView: NSViewRepresentable {
    let onKeyEvent: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.onKeyEvent = onKeyEvent
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}

class KeyEventView: NSView {
    var onKeyEvent: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let handler = onKeyEvent, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
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