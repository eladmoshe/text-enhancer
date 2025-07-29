import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .padding(.top, 2)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var shortcuts: [ShortcutConfiguration]
    @State private var showingAddShortcut = false
    @State private var editingShortcut: ShortcutConfiguration?
    @State private var maxTokens: Int
    @State private var timeout: Double
    @State private var showStatusIcon: Bool
    @State private var enableNotifications: Bool
    @State private var claudeApiKey: String
    @State private var openaiApiKey: String
    @State private var claudeEnabled: Bool
    @State private var openaiEnabled: Bool
    @State private var isTestingInProgress: Bool = false
    @State private var isClaudeKeyLocked: Bool = false
    @State private var isOpenaiKeyLocked: Bool = false
    @State private var shortcutsExpanded: Bool = true
    @State private var apiProvidersExpanded: Bool = false
    @State private var generalSettingsExpanded: Bool = false
    
    // Shared cache manager instance
    private let cacheManager = ModelCacheManager()
    
    init(configManager: ConfigurationManager) {
        self.configManager = configManager
        let config = configManager.configuration
        self._shortcuts = State(initialValue: config.shortcuts)
        self._maxTokens = State(initialValue: config.maxTokens)
        self._timeout = State(initialValue: config.timeout)
        self._showStatusIcon = State(initialValue: config.showStatusIcon)
        self._enableNotifications = State(initialValue: config.enableNotifications)
        self._claudeApiKey = State(initialValue: config.apiProviders.claude.apiKey)
        self._openaiApiKey = State(initialValue: config.apiProviders.openai.apiKey)
        self._claudeEnabled = State(initialValue: config.apiProviders.claude.enabled)
        self._openaiEnabled = State(initialValue: config.apiProviders.openai.enabled)
        self._isClaudeKeyLocked = State(initialValue: !config.apiProviders.claude.apiKey.isEmpty)
        self._isOpenaiKeyLocked = State(initialValue: !config.apiProviders.openai.apiKey.isEmpty)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TextEnhancer Settings")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Shortcuts Section
                    CollapsibleSection(
                        title: "Shortcuts",
                        isExpanded: $shortcutsExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Configure keyboard shortcuts and their prompts")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Add Shortcut") {
                                    showingAddShortcut = true
                                }
                                .buttonStyle(.bordered)
                                .font(.subheadline)
                            }
                            
                            if shortcuts.isEmpty {
                                Text("No shortcuts configured")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(shortcuts, id: \.id) { shortcut in
                                        ShortcutRowView(
                                            shortcut: shortcut,
                                            onEdit: { editingShortcut = shortcut },
                                            onDelete: {
                                                deleteShortcut(shortcut)
                                                saveConfiguration()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // API Providers Section
                    CollapsibleSection(
                        title: "API Providers",
                        isExpanded: $apiProvidersExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Claude Configuration
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Toggle("Enable Claude", isOn: $claudeEnabled)
                                        .toggleStyle(.switch)
                                        .font(.subheadline)
                                        .onChange(of: claudeEnabled) { _ in saveConfiguration() }
                                    Spacer()
                                }
                                
                                if claudeEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("API Key:")
                                                .font(.subheadline)
                                                .frame(width: 80, alignment: .leading)
                                            
                                            if isClaudeKeyLocked {
                                                SecureField("API key is set", text: .constant("••••••••••••••••"))
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.subheadline)
                                                    .disabled(true)
                                            } else {
                                                SecureField("Enter Claude API key", text: $claudeApiKey)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.subheadline)
                                                    .onChange(of: claudeApiKey) { _ in 
                                                        saveConfiguration()
                                                        if !claudeApiKey.isEmpty {
                                                            isClaudeKeyLocked = true
                                                        } else {
                                                            isClaudeKeyLocked = false
                                                        }
                                                    }
                                            }
                                            
                                            Button(action: {
                                                if isClaudeKeyLocked {
                                                    isClaudeKeyLocked = false
                                                } else {
                                                    if !claudeApiKey.isEmpty {
                                                        isClaudeKeyLocked = true
                                                    }
                                                }
                                            }) {
                                                Image(systemName: isClaudeKeyLocked ? "lock.fill" : "lock.open.fill")
                                                    .foregroundColor(isClaudeKeyLocked ? .orange : .secondary)
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            .help(isClaudeKeyLocked ? "Click to unlock and edit API key" : "Click to lock API key")
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            
                            Divider()
                            
                            // OpenAI Configuration
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Toggle("Enable OpenAI", isOn: $openaiEnabled)
                                        .toggleStyle(.switch)
                                        .font(.subheadline)
                                        .onChange(of: openaiEnabled) { _ in saveConfiguration() }
                                    Spacer()
                                }
                                
                                if openaiEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("API Key:")
                                                .font(.subheadline)
                                                .frame(width: 80, alignment: .leading)
                                            
                                            if isOpenaiKeyLocked {
                                                SecureField("API key is set", text: .constant("••••••••••••••••"))
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.subheadline)
                                                    .disabled(true)
                                            } else {
                                                SecureField("Enter OpenAI API key", text: $openaiApiKey)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.subheadline)
                                                    .onChange(of: openaiApiKey) { _ in 
                                                        saveConfiguration()
                                                        if !openaiApiKey.isEmpty {
                                                            isOpenaiKeyLocked = true
                                                        } else {
                                                            isOpenaiKeyLocked = false
                                                        }
                                                    }
                                            }
                                            
                                            Button(action: {
                                                if isOpenaiKeyLocked {
                                                    isOpenaiKeyLocked = false
                                                } else {
                                                    if !openaiApiKey.isEmpty {
                                                        isOpenaiKeyLocked = true
                                                    }
                                                }
                                            }) {
                                                Image(systemName: isOpenaiKeyLocked ? "lock.fill" : "lock.open.fill")
                                                    .foregroundColor(isOpenaiKeyLocked ? .green : .secondary)
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            .help(isOpenaiKeyLocked ? "Click to unlock and edit API key" : "Click to lock API key")
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // General Settings Section
                    CollapsibleSection(
                        title: "General Settings",
                        isExpanded: $generalSettingsExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Max Tokens:")
                                    .font(.subheadline)
                                    .frame(width: 100, alignment: .leading)
                                TextField("1000", value: $maxTokens, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .font(.subheadline)
                                    .onChange(of: maxTokens) { _ in saveConfiguration() }
                                Spacer()
                            }
                            
                            HStack {
                                Text("Timeout:")
                                    .font(.subheadline)
                                    .frame(width: 100, alignment: .leading)
                                TextField("30", value: $timeout, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .font(.subheadline)
                                    .onChange(of: timeout) { _ in saveConfiguration() }
                                Text("seconds")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Toggle("Show Status Icon", isOn: $showStatusIcon)
                                .font(.subheadline)
                                .onChange(of: showStatusIcon) { _ in saveConfiguration() }
                            Toggle("Enable Notifications", isOn: $enableNotifications)
                                .font(.subheadline)
                                .onChange(of: enableNotifications) { _ in saveConfiguration() }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingAddShortcut) {
            ShortcutEditView(
                shortcut: nil,
                onSave: { newShortcut in
                    shortcuts.append(newShortcut)
                    saveConfiguration()
                    showingAddShortcut = false
                },
                onCancel: { showingAddShortcut = false }
            )
        }
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditView(
                shortcut: shortcut,
                onSave: { editedShortcut in
                    if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                        shortcuts[index] = editedShortcut
                        saveConfiguration()
                    }
                    editingShortcut = nil
                },
                onCancel: { editingShortcut = nil }
            )
        }
    }
    
    
    private func deleteShortcut(_ shortcut: ShortcutConfiguration) {
        shortcuts.removeAll { $0.id == shortcut.id }
    }
    
    
    private func saveConfiguration() {
        let newConfig = AppConfiguration(
            shortcuts: shortcuts,
            maxTokens: maxTokens,
            timeout: timeout,
            showStatusIcon: showStatusIcon,
            enableNotifications: enableNotifications,
            autoSave: configManager.configuration.autoSave,
            logLevel: configManager.configuration.logLevel,
            apiProviders: APIProviders(
                claude: APIProviderConfig(
                    apiKey: claudeApiKey,
                    model: "claude-sonnet-4-20250514", // Default model for global config
                    enabled: claudeEnabled
                ),
                openai: APIProviderConfig(
                    apiKey: openaiApiKey,
                    model: "gpt-4o", // Default model for global config
                    enabled: openaiEnabled
                )
            )
        )
        
        configManager.configuration = newConfig
        configManager.saveConfiguration(newConfig)
    }
}

struct ShortcutRowView: View {
    let shortcut: ShortcutConfiguration
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shortcut.name)
                        .font(.title3)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatShortcutDisplay(shortcut.modifiers, shortcut.keyCode))
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                }
                
                HStack(spacing: 8) {
                    // Provider and model tag
                    let providerTextColor: Color = {
                        switch shortcut.provider {
                        case .claude:
                            return .orange
                        case .openai:
                            return .black
                        }
                    }()
                    let providerBackground: Color = {
                        switch shortcut.provider {
                        case .claude:
                            return .orange.opacity(0.1)
                        case .openai:
                            return .clear
                        }
                    }()

                    let tagContent = HStack(spacing: 4) {
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

                    if shortcut.provider == .openai {
                        tagContent
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            )
                    } else {
                        tagContent
                            .background(providerBackground)
                            .foregroundColor(providerTextColor)
                            .cornerRadius(10)
                    }
                    
                    if shortcut.effectiveIncludeScreenshot {
                        HStack(spacing: 4) {
                            Image(systemName: "camera")
                                .font(.caption2)
                            Text("Screenshot")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                
                Text(shortcut.prompt)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            VStack(spacing: 6) {
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .font(.subheadline)
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    private func formatModelName(_ model: String) -> String {
        switch model {
        case "claude-sonnet-4-20250514": return "Sonnet"
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
    
    private func formatShortcutDisplay(_ modifiers: [ModifierKey], _ keyCode: Int) -> String {
        let modifierString = modifiers.map { $0.displayName }.joined()
        let keyName = keyCodeToString(keyCode)
        return "\(modifierString)\(keyName)"
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "5"
        case 23: return "6"
        case 24: return "7"
        case 25: return "8"
        case 26: return "9"
        case 29: return "0"
        default: return "Key\(keyCode)"
        }
    }
}

struct ShortcutEditView: View {
    let shortcut: ShortcutConfiguration?
    let onSave: (ShortcutConfiguration) -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var prompt: String
    @State private var provider: APIProvider
    @State private var model: String
    @State private var includeScreenshot: Bool
    @State private var selectedModifiers: Set<ModifierKey>
    @State private var selectedKeyCode: Int
    @State private var availableClaudeModels: [ClaudeModel] = []
    @State private var availableOpenAIModels: [OpenAIModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var showTestSection: Bool = false
    @State private var testText: String = ""
    @State private var testResult: String = ""
    @State private var isTestingInProgress: Bool = false
    
    // Shared cache manager instance
    private let cacheManager = ModelCacheManager()
    
    init(shortcut: ShortcutConfiguration?, onSave: @escaping (ShortcutConfiguration) -> Void, onCancel: @escaping () -> Void) {
        self.shortcut = shortcut
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let shortcut = shortcut {
            self._name = State(initialValue: shortcut.name)
            self._prompt = State(initialValue: shortcut.prompt)
            self._provider = State(initialValue: shortcut.provider)
            self._model = State(initialValue: shortcut.model)
            self._includeScreenshot = State(initialValue: shortcut.effectiveIncludeScreenshot)
            self._selectedModifiers = State(initialValue: Set(shortcut.modifiers))
            self._selectedKeyCode = State(initialValue: shortcut.keyCode)
        } else {
            self._name = State(initialValue: "")
            self._prompt = State(initialValue: "")
            self._provider = State(initialValue: .claude)
            self._model = State(initialValue: "claude-sonnet-4-20250514")
            self._includeScreenshot = State(initialValue: false)
            self._selectedModifiers = State(initialValue: [.control, .option])
            self._selectedKeyCode = State(initialValue: 18)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(shortcut != nil ? "Edit Shortcut" : "Add New Shortcut")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                Button("Save") {
                    saveShortcut()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Information
                    GroupBox("Basic Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Name:")
                                    .frame(width: 80, alignment: .leading)
                                TextField("Enter shortcut name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Provider:")
                                    .frame(width: 80, alignment: .leading)
                                Picker("Provider", selection: $provider) {
                                    ForEach(APIProvider.allCases, id: \.self) { provider in
                                        Text(provider.displayName).tag(provider)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: provider) { newProvider in
                                    // Update model to default for the new provider
                                    model = newProvider == .claude ? "claude-sonnet-4-20250514" : "gpt-4o"
                                    
                                    // Fetch models when provider changes
                                    Task {
                                        await fetchModels()
                                    }
                                }
                            }
                            
                            HStack {
                                Text("Model:")
                                    .frame(width: 80, alignment: .leading)
                                HStack {
                                    Picker("Model", selection: $model) {
                                        if provider == .claude {
                                            if availableClaudeModels.isEmpty {
                                                Text("Loading models...").tag("")
                                            } else {
                                                ForEach(availableClaudeModels) { claudeModel in
                                                    Text(claudeModel.displayName).tag(claudeModel.id)
                                                }
                                            }
                                        } else {
                                            if availableOpenAIModels.isEmpty {
                                                Text("Loading models...").tag("")
                                            } else {
                                                ForEach(availableOpenAIModels) { openAIModel in
                                                    Text(openAIModel.displayName).tag(openAIModel.id)
                                                }
                                            }
                                        }
                                    }
                                    .disabled((provider == .claude && availableClaudeModels.isEmpty) || (provider == .openai && availableOpenAIModels.isEmpty))
                                    
                                    if (provider == .claude && (isLoadingModels || availableClaudeModels.isEmpty)) || (provider == .openai && (isLoadingModels || availableOpenAIModels.isEmpty)) {
                                        Button("🔄") {
                                            Task {
                                                await fetchModels()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .help("Refresh \(provider.displayName) models")
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle("Include Screenshot", isOn: $includeScreenshot)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Keyboard Shortcut
                    GroupBox("Keyboard Shortcut") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Modifiers:")
                                .font(.headline)
                            
                            HStack {
                                ForEach(ModifierKey.allCases, id: \.self) { modifier in
                                    Toggle(modifier.displayName, isOn: Binding(
                                        get: { selectedModifiers.contains(modifier) },
                                        set: { isOn in
                                            if isOn {
                                                selectedModifiers.insert(modifier)
                                            } else {
                                                selectedModifiers.remove(modifier)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                }
                            }
                            
                            HStack {
                                Text("Key:")
                                    .frame(width: 80, alignment: .leading)
                                Picker("Key", selection: $selectedKeyCode) {
                                    ForEach(1...9, id: \.self) { number in
                                        Text("\(number)").tag(17 + number)
                                    }
                                    Text("0").tag(29)
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Preview:")
                                    .frame(width: 80, alignment: .leading)
                                Text(formatShortcutDisplay(Array(selectedModifiers), selectedKeyCode))
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(4)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Prompt
                    GroupBox("Prompt") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter the prompt that will be sent to the AI:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $prompt)
                                .frame(minHeight: 100)
                                .font(.system(.body, design: .monospaced))
                                .border(Color(.separatorColor), width: 1)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Test Section
                    CollapsibleSection(
                        title: "Test Prompt",
                        isExpanded: $showTestSection
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test your prompt while editing to see how it works")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Text:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextEditor(text: $testText)
                                    .frame(minHeight: 60)
                                    .font(.system(.body, design: .monospaced))
                                    .border(Color(.separatorColor), width: 1)
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                Button("Test Current Prompt") {
                                    Task {
                                        await runTest()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(testText.isEmpty || prompt.isEmpty || isTestingInProgress)
                                
                                if isTestingInProgress {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.leading, 8)
                                }
                                
                                Spacer()
                                
                                Button("Clear") {
                                    testText = ""
                                    testResult = ""
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if !testResult.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Result:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    ScrollView {
                                        Text(testResult)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxHeight: 150)
                                    .border(Color(.separatorColor), width: 1)
                                    .cornerRadius(4)
                                    .background(Color(.controlBackgroundColor).opacity(0.5))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            Task {
                await preloadCachedModels()
                await fetchModels()
            }
        }
    }
    
    @MainActor
    private func preloadCachedModels() async {
        // Load cached models immediately if available
        if let cachedClaudeModels = cacheManager.getCachedClaudeModels() {
            availableClaudeModels = cachedClaudeModels
            print("✅ ShortcutEditView: Preloaded \(cachedClaudeModels.count) cached Claude models")
        }
        
        if let cachedOpenAIModels = cacheManager.getCachedOpenAIModels() {
            availableOpenAIModels = cachedOpenAIModels
            print("✅ ShortcutEditView: Preloaded \(cachedOpenAIModels.count) cached OpenAI models")
        }
    }
    
    private func saveShortcut() {
        let id = shortcut?.id ?? UUID().uuidString
        let newShortcut = ShortcutConfiguration(
            id: id,
            name: name,
            keyCode: selectedKeyCode,
            modifiers: Array(selectedModifiers),
            prompt: prompt,
            provider: provider,
            model: model,
            includeScreenshot: includeScreenshot
        )
        onSave(newShortcut)
    }
    
    private func runTest() async {
        guard !testText.isEmpty && !prompt.isEmpty else { return }
        
        await MainActor.run {
            isTestingInProgress = true
            testResult = ""
        }
        
        defer {
            Task { @MainActor in
                isTestingInProgress = false
            }
        }
        
        do {
            // Create a temporary config manager for testing
            let tempConfigManager = ConfigurationManager()
            guard let apiService = APIProviderFactory.createService(for: provider, configManager: tempConfigManager) else {
                await MainActor.run {
                    testResult = "Error: API provider \(provider.displayName) is not configured or enabled. Please configure it in the main settings first."
                }
                return
            }
            
            let enhancedText = try await apiService.enhanceText(testText, with: prompt, using: model)
            
            await MainActor.run {
                testResult = enhancedText
            }
        } catch {
            await MainActor.run {
                testResult = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    private func fetchModels() async {
        switch provider {
        case .claude:
            await fetchClaudeModels()
        case .openai:
            await fetchOpenAIModels()
        }
    }
    
    @MainActor
    private func fetchClaudeModels() async {
        isLoadingModels = true
        
        do {
            // Create a temporary config manager for API calls
            let tempConfigManager = ConfigurationManager()
            let claudeService = ClaudeService(configManager: tempConfigManager, cacheManager: cacheManager)
            let models = try await claudeService.fetchAvailableModels()
            availableClaudeModels = models
            
            // Update the selected model if it's not available in the new list
            if !models.contains(where: { $0.id == model }) && !models.isEmpty {
                model = models.first?.id ?? model
            }
            
            print("✅ ShortcutEditView: Loaded \(models.count) Claude models")
        } catch {
            print("❌ ShortcutEditView: Failed to fetch Claude models: \(error)")
            // Keep existing models if fetch fails
        }
        
        isLoadingModels = false
    }
    
    @MainActor
    private func fetchOpenAIModels() async {
        isLoadingModels = true
        
        do {
            // Create a temporary config manager for API calls
            let tempConfigManager = ConfigurationManager()
            let openAIService = OpenAIService(configManager: tempConfigManager, cacheManager: cacheManager)
            let models = try await openAIService.fetchAvailableModels()
            availableOpenAIModels = models
            
            // Update the selected model if it's not available in the new list
            if !models.contains(where: { $0.id == model }) && !models.isEmpty {
                model = models.first?.id ?? model
            }
            
            print("✅ ShortcutEditView: Loaded \(models.count) OpenAI models")
        } catch {
            print("❌ ShortcutEditView: Failed to fetch OpenAI models: \(error)")
            // Keep existing models if fetch fails
        }
        
        isLoadingModels = false
    }
    
    private func formatShortcutDisplay(_ modifiers: [ModifierKey], _ keyCode: Int) -> String {
        let modifierString = modifiers.map { $0.displayName }.joined()
        let keyName = keyCodeToString(keyCode)
        return "\(modifierString)\(keyName)"
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "5"
        case 23: return "6"
        case 24: return "7"
        case 25: return "8"
        case 26: return "9"
        case 29: return "0"
        default: return "Key\(keyCode)"
        }
    }
}

#Preview {
    SettingsView(configManager: ConfigurationManager())
}