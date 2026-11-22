import Foundation

struct TodoRepository: Sendable {
    let url: URL

    @concurrent func load() async throws -> TodoBoard {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            return TodoBoard()
        }
        let decoder = JSONDecoder()
        if let legacy = try? decoder.decode([LocalTodo].self, from: data) {
            return try TodoBoard(items: legacy).validated()
        }
        return try decoder.decode(TodoBoard.self, from: data).validated()
    }

    @concurrent func save(_ board: TodoBoard) async throws {
        let data = try JSONEncoder().encode(board.validated())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
