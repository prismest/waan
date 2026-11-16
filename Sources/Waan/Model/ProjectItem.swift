import SwiftUI

public struct ProjectItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var color: String
    public var icon: String
    public var createdAt: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "blue",
        icon: String = "folder.fill",
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }

    public static let presetColors: [String] = ["blue", "purple", "pink", "orange", "green", "gray"]
    public static let presetIcons: [String] = [
        "folder.fill", "briefcase.fill", "hammer.fill", "book.fill",
        "globe", "star.fill", "sparkles", "heart.fill"
    ]

    public var displayColor: Color {
        Self.color(for: color)
    }

    public static func color(for name: String) -> Color {
        switch name.lowercased() {
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "gray": return .gray
        default: return .blue
        }
    }
}
