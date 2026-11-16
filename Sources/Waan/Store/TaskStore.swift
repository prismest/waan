import SwiftUI

public enum FilterType: String, CaseIterable, Identifiable {
    case all = "All Tasks"
    case today = "Today"
    case pending = "Pending"
    case highPriority = "High Priority"
    case completed = "Completed"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .today: return "sun.max.fill"
        case .pending: return "circle"
        case .highPriority: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    public func localizedTitle(for lang: AppLanguage) -> String {
        switch self {
        case .all: return lang == .th ? "งานทั้งหมด" : "All Tasks"
        case .today: return lang == .th ? "วันนี้" : "Today"
        case .pending: return lang == .th ? "รอดำเนินการ" : "Pending"
        case .highPriority: return lang == .th ? "สำคัญสูง" : "High Priority"
        case .completed: return lang == .th ? "เสร็จแล้ว" : "Completed"
        }
    }
}

@MainActor
public final class TaskStore: ObservableObject {
    public static let shared = TaskStore()

    @Published public var tasks: [TaskItem] = []
    @Published public var projects: [ProjectItem] = []
    @Published public var selectedFilter: FilterType = .today
    @Published public var selectedProjectId: String? = nil
    @Published public var searchText: String = ""

    private let db: DatabaseManager
    private var fileWatcher: FileWatcher?

    public init(db: DatabaseManager = .shared) {
        self.db = db
        reloadTasks()

        fileWatcher = FileWatcher(filePath: db.dbPath) { [weak self] in
            DispatchQueue.main.async {
                self?.reloadTasks()
            }
        }
    }

    public func reloadTasks() {
        self.tasks = db.fetchAllTasks()
        self.projects = db.fetchAllProjects()
    }

    public var pendingTasksCount: Int {
        tasks.reduce(0) { $0 + ($1.isCompleted ? 0 : 1) }
    }

    public func recommendedTask(now: Date = Date()) -> RecommendedTask? {
        NextTaskRecommender.recommend(from: tasks, now: now)
    }

    public var groupedCompletedTasks: [CompletedTaskGroup] {
        CompletedTasksGrouper.group(tasks: filteredTasks)
    }

    public var filteredTasks: [TaskItem] {
        var result = tasks

        if let pid = selectedProjectId {
            result = result.filter { $0.projectId == pid }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.subtasks.contains(where: { $0.title.lowercased().contains(query) }) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        if selectedProjectId != nil {
            return result.sorted {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted
                }
                return ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
            }
        }

        switch selectedFilter {
        case .all:
            return result
        case .today:
            let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
            return result.filter { !$0.isCompleted && (($0.dueDate?.starts(with: todayStr) ?? true) || $0.priority == .urgent) }
        case .pending:
            return result.filter { !$0.isCompleted }
        case .highPriority:
            return result.filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .urgent) }
        case .completed:
            return result
                .filter(\.isCompleted)
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        }
    }

    public var todayTasksCount: Int {
        let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        return tasks.filter { !$0.isCompleted && (($0.dueDate?.starts(with: todayStr) ?? true) || $0.priority == .urgent) }.count
    }

    public func project(for id: String?) -> ProjectItem? {
        guard let id = id else { return nil }
        return projects.first { $0.id == id }
    }

    public func projectProgress(id: String) -> (done: Int, total: Int, percent: Double) {
        let pTasks = tasks.filter { $0.projectId == id }
        let done = pTasks.filter(\.isCompleted).count
        let total = pTasks.count
        let percent = total > 0 ? Double(done) / Double(total) : 0.0
        return (done, total, percent)
    }

    public func addTask(
        title: String,
        dueDate: String? = nil,
        priority: Priority = .normal,
        subtasks: [String] = [],
        tags: [String] = [],
        projectId: String? = nil
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let subtaskItems = subtasks.map { SubtaskItem(title: $0) }
        let task = TaskItem(
            title: trimmed,
            dueDate: dueDate,
            priority: priority,
            subtasks: subtaskItems,
            tags: tags,
            projectId: projectId ?? selectedProjectId
        )
        db.insert(task: task)
        reloadTasks()
    }

    @discardableResult
    public func addProject(name: String, color: String = "blue", icon: String = "folder.fill") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let project = ProjectItem(name: trimmed, color: color, icon: icon)
        db.insert(project: project)
        reloadTasks()
        return project.id
    }

    public func deleteProject(id: String) {
        db.deleteProject(id: id)
        if selectedProjectId == id {
            selectedProjectId = nil
        }
        reloadTasks()
    }

    public func updateTaskProject(taskId: String, projectId: String?) {
        db.updateTaskProject(taskId: taskId, projectId: projectId)
        reloadTasks()
    }

    public func toggleTask(id: String) {
        db.toggleTask(id: id)
        reloadTasks()
    }

    public func toggleSubtask(taskId: String, subtaskId: String) {
        db.toggleSubtask(taskId: taskId, subtaskId: subtaskId)
        reloadTasks()
    }

    public func updateTags(id: String, tags: [String]) {
        db.updateTaskTags(id: id, tags: tags)
        reloadTasks()
    }

    public func deleteTask(id: String) {
        db.delete(id: id)
        reloadTasks()
    }
}

