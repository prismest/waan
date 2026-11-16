import SwiftUI

private enum SidebarDestination: Hashable {
    case now
    case tasks(FilterType)
    case project(String)
    case focusInsights
}

public struct MainWindowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var pomodoro: PomodoroManager = .shared
    @ObservedObject var mcpServer: MCPServerManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    @State private var showingAIGuide: Bool = false
    @State private var showingChat: Bool = false
    @State private var showingNewProject: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var destination: SidebarDestination = .now

    public var body: some View {
        Group {
            if pomodoro.state != .idle {
                FocusModeView(store: store, pomodoro: pomodoro)
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $destination) {
                    Label(langManager.text(.focusNow), systemImage: "scope")
                        .font(.system(size: 13))
                        .tag(SidebarDestination.now)
                        .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 4)

                    ForEach(FilterType.allCases) { filter in
                        HStack {
                            Label(filter.localizedTitle(for: langManager.currentLanguage), systemImage: filter.iconName)
                                .font(.system(size: 13))
                            Spacer()
                            countLabel(for: filter)
                        }
                        .tag(SidebarDestination.tasks(filter))
                        .padding(.vertical, 2)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Label(langManager.text(.focusInsights), systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13))
                        .tag(SidebarDestination.focusInsights)
                        .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 4)

                    Section(header: HStack {
                        Text(langManager.currentLanguage == .th ? "โปรเจกต์" : "Projects")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { showingNewProject = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(langManager.currentLanguage == .th ? "สร้างโปรเจกต์ใหม่" : "New Project")
                    }) {
                        ForEach(store.projects) { project in
                            let progress = store.projectProgress(id: project.id)
                            HStack(spacing: 8) {
                                Image(systemName: project.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(project.displayColor)
                                Text(project.name)
                                    .font(.system(size: 13))
                                Spacer()
                                if progress.total > 0 {
                                    Text("\(progress.done)/\(progress.total)")
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                            .tag(SidebarDestination.project(project.id))
                            .padding(.vertical, 2)
                            .contextMenu {
                                Button(langManager.currentLanguage == .th ? "ลบโปรเจกต์" : "Delete Project") {
                                    store.deleteProject(id: project.id)
                                    if case .project(let pid) = destination, pid == project.id {
                                        destination = .tasks(.all)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: destination) {
                    switch destination {
                    case .tasks(let filter):
                        store.selectedProjectId = nil
                        store.selectedFilter = filter
                    case .project(let pid):
                        store.selectedProjectId = pid
                    case .now, .focusInsights:
                        store.selectedProjectId = nil
                    }
                }

                Divider()
                    .opacity(0.4)

                PomodoroControlCard(compact: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()
                    .opacity(0.4)

                HStack(spacing: 6) {
                    Circle()
                        .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text("MCP")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Button(action: { showingAIGuide.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("MCP & AI Config")

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { mcpServer.isRunning },
                        set: { $0 ? mcpServer.start() : mcpServer.stop() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .help(mcpServer.isRunning ? "Stop MCP Server" : "Start MCP Server")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 230)
        } detail: {
            HStack(spacing: 0) {
                Group {
                    switch destination {
                    case .now:
                        FocusNowView(store: store)
                    case .focusInsights:
                        FocusAnalyticsView(store: store)
                    case .tasks, .project:
                        taskListColumn
                            .searchable(text: $store.searchText, prompt: langManager.text(.searchPlaceholder))
                    }
                }
                .frame(minWidth: 280, maxWidth: .infinity)

                if showingChat {
                    Divider()
                    ChatAssistantView()
                        .frame(minWidth: 260, idealWidth: 310, maxWidth: 380)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { langManager.toggle() } }) {
                        Text(langManager.currentLanguage == .th ? "TH" : "EN")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .help("Switch Language (ไทย / English)")

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingChat.toggle() } }) {
                        Label(langManager.text(.aiChat), systemImage: "sparkles")
                    }
                    .tint(showingChat ? .accentColor : .secondary)
                    .help(langManager.text(.aiChat))
                }
            }
            .sheet(isPresented: $showingAIGuide) {
                AIGuideSheetView(mcpServer: mcpServer)
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectSheet(store: store) { newId in
                    destination = .project(newId)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pomodoro.state == .idle)
        .frame(minWidth: 720, minHeight: 480)
    }

    private var taskListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let pid = store.selectedProjectId, let project = store.project(for: pid) {
                projectHeader(project)
            } else {
                standardHeader
            }

            QuickInputBar(store: store)
                .padding(.horizontal, 24)

            if store.filteredTasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(langManager.currentLanguage == .th ? "ไม่มีงานในรายการนี้" : "Nothing here yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if store.selectedFilter == .completed {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(store.groupedCompletedTasks) { group in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(group.bucket.localizedTitle(for: langManager.currentLanguage))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Text("\(group.tasks.count)")
                                            .font(.system(size: 11, weight: .medium))
                                            .monospacedDigit()
                                            .foregroundColor(.secondary.opacity(0.6))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)

                                    LazyVStack(spacing: 0) {
                                        ForEach(group.tasks) { task in
                                            TaskRowView(store: store, task: task)
                                            Divider()
                                                .opacity(0.3)
                                                .padding(.leading, 32)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(store.filteredTasks) { task in
                                TaskRowView(store: store, task: task)
                                Divider()
                                    .opacity(0.3)
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
            }
        }
    }

    private func projectHeader(_ project: ProjectItem) -> some View {
        let progress = store.projectProgress(id: project.id)
        let isTh = langManager.currentLanguage == .th
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: project.icon)
                    .foregroundColor(project.displayColor)
                    .font(.system(size: 18))
                Text(project.name)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if progress.total > 0 {
                    Text(isTh
                         ? "\(progress.done)/\(progress.total) งาน (\(Int(progress.percent * 100))%)"
                         : "\(progress.done)/\(progress.total) done (\(Int(progress.percent * 100))%)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }

            if progress.total > 0 {
                ProgressView(value: progress.percent)
                    .tint(project.displayColor)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var standardHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(store.selectedFilter.localizedTitle(for: langManager.currentLanguage))
                .font(.system(size: 20, weight: .bold))
            Text("\(store.filteredTasks.count)")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func countLabel(for filter: FilterType) -> some View {
        let count: Int = {
            switch filter {
            case .all: return store.tasks.count
            case .today: return store.todayTasksCount
            case .pending: return store.tasks.filter { !$0.isCompleted }.count
            case .highPriority: return store.tasks.filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .urgent) }.count
            case .completed: return store.tasks.filter { $0.isCompleted }.count
            }
        }()

        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

struct CopyButton: View {
    let text: String
    let label: String
    @State private var copied = false

    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        }) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied!" : label)
            }
            .font(.system(size: 11))
            .foregroundColor(copied ? .green : .accentColor)
        }
        .buttonStyle(.plain)
    }
}

struct AIGuideSheetView: View {
    @ObservedObject var mcpServer: MCPServerManager
    @Environment(\.dismiss) private var dismiss

    private var claudeConfigJson: String {
        let script = mcpServer.resolveScriptPath()
        return """
{
  "mcpServers": {
    "waan": {
      "command": "python3",
      "args": ["\(script)"]
    }
  }
}
"""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                Text("AI Harness Connection Guide (MCP)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(mcpServer.isRunning ? "MCP Server Active on port \(String(mcpServer.port))" : "MCP Server is Stopped (toggle ON in sidebar)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("1. Claude Desktop Config (Stdio):")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            CopyButton(text: claudeConfigJson, label: "Copy Config")
                        }

                        Text("Add to ~/Library/Application Support/Claude/claude_desktop_config.json:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text(claudeConfigJson)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("2. Cursor / SSE Remote Integration:")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            CopyButton(text: "http://127.0.0.1:\(mcpServer.port)/sse", label: "Copy SSE URL")
                        }

                        Text("SSE Endpoint: http://127.0.0.1:\(mcpServer.port)/sse")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("3. Terminal Control:")
                            .font(.system(size: 12, weight: .semibold))
                        Text("./bin/waan mcp start  |  ./bin/waan mcp stop  |  ./bin/waan mcp status")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 540, height: 420)
    }
}

private struct NewProjectSheet: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var langManager: LanguageManager = .shared
    @Environment(\.dismiss) private var dismiss
    let onCreated: (String) -> Void

    @State private var name: String = ""
    @State private var selectedColor: String = "blue"
    @State private var selectedIcon: String = "folder.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(langManager.currentLanguage == .th ? "สร้างโปรเจกต์ใหม่" : "New Project")
                .font(.system(size: 15, weight: .semibold))

            TextField(langManager.currentLanguage == .th ? "ชื่อโปรเจกต์..." : "Project name...", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text(langManager.currentLanguage == .th ? "สี" : "Color")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(ProjectItem.presetColors, id: \.self) { c in
                        Circle()
                            .fill(ProjectItem.color(for: c))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == c ? 2 : 0)
                            )
                            .onTapGesture { selectedColor = c }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(langManager.currentLanguage == .th ? "ไอคอน" : "Icon")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    ForEach(ProjectItem.presetIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(selectedIcon == icon ? ProjectItem.color(for: selectedColor) : .secondary)
                            .padding(5)
                            .background(selectedIcon == icon ? Color.secondary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            HStack {
                Spacer()
                Button(langManager.currentLanguage == .th ? "ยกเลิก" : "Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Button(langManager.currentLanguage == .th ? "สร้าง" : "Create") {
                    let newId = store.addProject(name: name, color: selectedColor, icon: selectedIcon)
                    dismiss()
                    if !newId.isEmpty { onCreated(newId) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: 300)
    }
}
