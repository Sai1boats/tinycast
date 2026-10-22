import Foundation

@main
@MainActor
struct TodosBridgeTests {
    private static var failures = 0

    static func main() async throws {
        try testSnapshotFixtureDecode()
        try testRoundtrip()
        try testUnknownKeysAreTolerated()
        try testMissingOptionalFields()
        try testBucketRawValues()
        testErrorCodes()
        try testCommandEncodingKeys()
        try testCommandValidation()
        try testPayloadNotesEncoding()
        try testPaths()
        try testFileStore()
        try testDraftPayloads()
        testDraftSubtaskEdits()
        try testDraftNotesPayloads()
        try testDraftNotesSeeding()
        try testGrouping()
        try testDueLabelBoundaries()
        testIsOverdue()
        testSubtaskSummary()
        testQueryMatching()

        print(failures == 0 ? "Todos bridge tests passed" : "\(failures) tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Wire

    private static func testSnapshotFixtureDecode() throws {
        let taskID = try require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let sectionID = try require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let labelID = try require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let subtaskID = try require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let json = """
            {
              "schemaVersion": 1,
              "revision": 7,
              "generatedAt": "2026-10-19T08:00:00Z",
              "tasks": [
                {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "title": "Buy milk",
                  "notes": "whole",
                  "notesMarkdown": "# buy",
                  "startDate": "2026-10-18T08:00:00Z",
                  "dueDate": "2026-10-20T08:00:00Z",
                  "bucket": "week",
                  "boardSectionID": "22222222-2222-2222-2222-222222222222",
                  "labelID": "33333333-3333-3333-3333-333333333333",
                  "isCompleted": false,
                  "subtasks": [
                    {
                      "id": "44444444-4444-4444-4444-444444444444",
                      "title": "skim",
                      "isCompleted": true
                    }
                  ]
                }
              ],
              "labels": [
                {
                  "id": "33333333-3333-3333-3333-333333333333",
                  "name": "Errands",
                  "colorHex": "#FF0000"
                }
              ],
              "boardSections": [
                {"id": "22222222-2222-2222-2222-222222222222", "name": "Inbox", "isInbox": true}
              ]
            }
            """
        let snapshot = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeSnapshot.self, from: Data(json.utf8))
        check("a fixture snapshot decodes at schema v1", snapshot.schemaVersion == 1)
        check("the revision is a wire field", snapshot.revision == 7)
        let generatedAt = try isoDate("2026-10-19T08:00:00Z")
        let dueDate = try isoDate("2026-10-20T08:00:00Z")
        check("iso8601 dates decode", snapshot.generatedAt == generatedAt)
        let task = try require(snapshot.tasks.first)
        check("a fixture task decodes whole", task.id == taskID && task.title == "Buy milk")
        check("rich notes ride along read-only", task.notesMarkdown == "# buy")
        check("a due date decodes iso8601", task.dueDate == dueDate)
        check("a bucket decodes from its raw value", task.bucket == .week)
        check("a section id is a wire field", task.boardSectionID == sectionID)
        check("a label id is a wire field", task.labelID == labelID)
        check(
            "subtasks decode in order",
            task.subtasks == [TodoBridgeSubtask(id: subtaskID, title: "skim", isCompleted: true)])
        check(
            "labels and board sections decode",
            snapshot.labels == [TodoBridgeLabel(id: labelID, name: "Errands", colorHex: "#FF0000")]
                && snapshot.boardSections == [
                    TodoBridgeBoardSection(id: sectionID, name: "Inbox", isInbox: true)
                ])
    }

    private static func testRoundtrip() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let task = TodoBridgeTask(
            id: UUID(), title: "Task", notes: "n", notesMarkdown: "*m*", startDate: now,
            dueDate: now.addingTimeInterval(3600), bucket: .today, boardSectionID: UUID(),
            labelID: UUID(), isCompleted: true,
            subtasks: [TodoBridgeSubtask(id: UUID(), title: "s", isCompleted: false)])
        let snapshot = TodoBridgeSnapshot(
            schemaVersion: 1, revision: 2, generatedAt: now, tasks: [task],
            labels: [TodoBridgeLabel(id: UUID(), name: "L", colorHex: "#00FF00")],
            boardSections: [TodoBridgeBoardSection(id: UUID(), name: "Inbox", isInbox: true)])
        let status = TodoBridgeStatus(
            schemaVersion: 1, pid: 42, startedAt: now, lastHeartbeatAt: now, revision: 2)
        let payload = TodoBridgeTaskPayload(
            id: UUID(), title: "Task", startDate: now, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: task.subtasks)
        let command = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .create, sentAt: now, task: payload,
            taskID: nil, isCompleted: nil)
        let result = TodoBridgeResult(
            schemaVersion: 1, requestID: command.requestID, ok: false, completedAt: now,
            revision: 2, errorCode: TodoBridgeErrorCode.internal, errorMessage: "boom")
        let encoder = TodoBridgeProtocol.makeEncoder()
        let decoder = TodoBridgeProtocol.makeDecoder()
        let snapshotData = try encoder.encode(snapshot)
        check("a snapshot round-trips",
              try decoder.decode(TodoBridgeSnapshot.self, from: snapshotData) == snapshot)
        let statusData = try encoder.encode(status)
        check("a status round-trips",
              try decoder.decode(TodoBridgeStatus.self, from: statusData) == status)
        let commandData = try encoder.encode(command)
        check("a command round-trips",
              try decoder.decode(TodoBridgeCommand.self, from: commandData) == command)
        let resultData = try encoder.encode(result)
        check("a result round-trips",
              try decoder.decode(TodoBridgeResult.self, from: resultData) == result)
    }

    private static func testUnknownKeysAreTolerated() throws {
        let json = """
            {
              "futureTop": {"x": 1},
              "schemaVersion": 1,
              "revision": 3,
              "generatedAt": "2026-10-19T08:00:00Z",
              "tasks": [
                {
                  "futureTask": [1, 2],
                  "id": "11111111-1111-1111-1111-111111111111",
                  "title": "Kept",
                  "notes": "",
                  "bucket": "later",
                  "isCompleted": true,
                  "subtasks": [],
                  "futureNested": "ignored"
                }
              ],
              "labels": [],
              "boardSections": [],
              "futureBottom": true
            }
            """
        let snapshot = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeSnapshot.self, from: Data(json.utf8))
        check("unknown keys are tolerated", snapshot.tasks.map(\.title) == ["Kept"])
        check("known keys survive alongside unknown ones", snapshot.revision == 3)
    }

    private static func testMissingOptionalFields() throws {
        let json = """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Bare",
              "notes": "",
              "bucket": "today",
              "isCompleted": false,
              "subtasks": []
            }
            """
        let task = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeTask.self, from: Data(json.utf8))
        check("missing optional fields read as nil",
              task.notesMarkdown == nil && task.startDate == nil && task.dueDate == nil
                && task.boardSectionID == nil && task.labelID == nil)
        let commandJSON = """
            {
              "schemaVersion": 1,
              "requestID": "55555555-5555-5555-5555-555555555555",
              "kind": "setCompleted",
              "sentAt": "2026-10-19T08:00:00Z"
            }
            """
        let command = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeCommand.self, from: Data(commandJSON.utf8))
        check("missing command fields read as nil",
              command.task == nil && command.taskID == nil && command.isCompleted == nil)
        let resultJSON = """
            {
              "schemaVersion": 1,
              "requestID": "55555555-5555-5555-5555-555555555555",
              "ok": true,
              "completedAt": "2026-10-19T08:00:00Z",
              "revision": 4
            }
            """
        let result = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeResult.self, from: Data(resultJSON.utf8))
        check("an errorless result omits its error fields",
              result.errorCode == nil && result.errorMessage == nil && result.ok)
    }

    private static func testBucketRawValues() throws {
        check("bucket raw values name the wire spellings",
              TodoBridgeBucket.later.rawValue == "later"
                && TodoBridgeBucket.week.rawValue == "week"
                && TodoBridgeBucket.today.rawValue == "today")
        let decoder = TodoBridgeProtocol.makeDecoder()
        check("each bucket decodes from its raw string",
              try decoder.decode(TodoBridgeBucket.self, from: Data("\"later\"".utf8)) == .later
                && decoder.decode(TodoBridgeBucket.self, from: Data("\"week\"".utf8)) == .week
                && decoder.decode(TodoBridgeBucket.self, from: Data("\"today\"".utf8)) == .today)
    }

    private static func testErrorCodes() {
        check("error code strings match the contract",
              TodoBridgeErrorCode.invalidCommand == "invalidCommand"
                && TodoBridgeErrorCode.invalidTitle == "invalidTitle"
                && TodoBridgeErrorCode.taskNotFound == "taskNotFound"
                && TodoBridgeErrorCode.persistenceFailed == "persistenceFailed"
                && TodoBridgeErrorCode.internal == "internal")
    }

    private static func testCommandEncodingKeys() throws {
        let requestID = UUID()
        let taskID = UUID()
        let payload = TodoBridgeTaskPayload(
            id: taskID, title: "T", startDate: nil, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: [])
        let create = TodoBridgeCommand(
            schemaVersion: 1, requestID: requestID, kind: .create,
            sentAt: Date(timeIntervalSince1970: 1_760_000_000), task: payload,
            taskID: nil, isCompleted: nil)
        let createData = try TodoBridgeProtocol.makeEncoder().encode(create)
        let createDecoded = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        let createObject = try require(createDecoded)
        check("create carries its task alone",
              createObject["kind"] as? String == "create"
                && createObject["task"] is [String: Any]
                && createObject["taskID"] == nil && createObject["isCompleted"] == nil)
        let update = TodoBridgeCommand(
            schemaVersion: 1, requestID: requestID, kind: .update,
            sentAt: Date(timeIntervalSince1970: 1_760_000_000), task: payload,
            taskID: taskID, isCompleted: true)
        let data = try TodoBridgeProtocol.makeEncoder().encode(update)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let object = try require(decoded)
        check("a command encodes its kind", object["kind"] as? String == "update")
        check("a command encodes its task", object["task"] is [String: Any])
        check("a command encodes its taskID", object["taskID"] as? String == taskID.uuidString)
        check("a command encodes isCompleted", object["isCompleted"] as? Bool == true)
        let completed = TodoBridgeCommand(
            schemaVersion: 1, requestID: requestID, kind: .setCompleted,
            sentAt: Date(timeIntervalSince1970: 1_760_000_000), task: nil,
            taskID: taskID, isCompleted: false)
        let completedData = try TodoBridgeProtocol.makeEncoder().encode(completed)
        let completedDecoded =
            try JSONSerialization.jsonObject(with: completedData) as? [String: Any]
        let completedObject = try require(completedDecoded)
        check("nil optional fields are omitted", completedObject["task"] == nil)
        check("setCompleted carries its taskID and flag",
              completedObject["kind"] as? String == "setCompleted"
                && completedObject["taskID"] as? String == taskID.uuidString
                && completedObject["isCompleted"] as? Bool == false)
    }

    private static func testCommandValidation() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let payload = TodoBridgeTaskPayload(
            id: UUID(), title: "  ok  ", startDate: nil, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: [])
        let valid = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .create, sentAt: now,
            task: payload, taskID: nil, isCompleted: nil)
        check("a well-formed command validates", (try? TodoBridgeProtocol.validate(valid)) != nil)
        let future = TodoBridgeCommand(
            schemaVersion: 2, requestID: UUID(), kind: .create, sentAt: now,
            task: payload, taskID: nil, isCompleted: nil)
        check("a future schema is refused",
              (try? TodoBridgeProtocol.validate(future)) == nil)
        let emptyTitle = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .update, sentAt: now,
            task: TodoBridgeTaskPayload(
                id: UUID(), title: "   ", startDate: nil, dueDate: nil, boardSectionID: nil,
                labelID: nil, subtasks: []),
            taskID: nil, isCompleted: nil)
        check("a blank title is refused", (try? TodoBridgeProtocol.validate(emptyTitle)) == nil)
        let missingTask = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .create, sentAt: now,
            task: nil, taskID: nil, isCompleted: nil)
        check(
            "a create without a task is refused",
            (try? TodoBridgeProtocol.validate(missingTask)) == nil)
        let missingCompletion = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .setCompleted, sentAt: now,
            task: nil, taskID: UUID(), isCompleted: nil)
        check("setCompleted without a flag is refused",
              (try? TodoBridgeProtocol.validate(missingCompletion)) == nil)
    }

    private static func testPayloadNotesEncoding() throws {
        let decoder = TodoBridgeProtocol.makeDecoder()
        let bare = TodoBridgeTaskPayload(
            id: UUID(), title: "Bare", startDate: nil, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: [])
        let bareData = try TodoBridgeProtocol.makeEncoder().encode(bare)
        let bareDecoded = try JSONSerialization.jsonObject(with: bareData) as? [String: Any]
        let bareObject = try require(bareDecoded)
        check("nil notes markdown is omitted from the JSON",
              bareObject["notesMarkdown"] == nil)
        check("a bare payload decodes its nil notes",
              try decoder.decode(TodoBridgeTaskPayload.self, from: bareData).notesMarkdown == nil)
        let noted = TodoBridgeTaskPayload(
            id: UUID(), title: "Noted", startDate: nil, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: [], notesMarkdown: "# Plan")
        let notedData = try TodoBridgeProtocol.makeEncoder().encode(noted)
        let notedDecoded = try JSONSerialization.jsonObject(with: notedData) as? [String: Any]
        let notedObject = try require(notedDecoded)
        check("set notes markdown rides in the JSON",
              notedObject["notesMarkdown"] as? String == "# Plan")
        check("a noted payload round-trips its notes",
              try decoder.decode(TodoBridgeTaskPayload.self, from: notedData).notesMarkdown
                == "# Plan")
        let oldJSON = """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Legacy",
              "subtasks": [],
              "futureNote": {"x": 1}
            }
            """
        let legacy = try decoder.decode(TodoBridgeTaskPayload.self, from: Data(oldJSON.utf8))
        check("an old payload without the key reads nil notes", legacy.notesMarkdown == nil)
        check("unknown keys beside the new one are tolerated", legacy.title == "Legacy")
    }

    // MARK: - Files

    private static func testPaths() throws {
        let root = temporaryRoot("paths")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = TodoBridgePaths(homeDirectory: root)
        check(
            "the bridge root sits under the injected home",
            paths.baseURL.path
                == root.appending(path: "Library/Application Support/Planote/TodoBridge").path)
        check(
            "snapshot and status sit at the root",
            paths.snapshotURL.lastPathComponent == "snapshot.json"
                && paths.statusURL.lastPathComponent == "status.json")
        check(
            "commands and results hold the queues",
            paths.commandsDirectory.lastPathComponent == "commands"
                && paths.resultsDirectory.lastPathComponent == "results")
        let requestID = UUID()
        let filename = paths.commandFilename(
            for: requestID, at: Date(timeIntervalSince1970: 1_760_000_000))
        check("a command filename leads with zero-padded millis",
              filename.hasPrefix("1760000000000-"))
        check("a command filename carries the request id",
              filename == "1760000000000-" + requestID.uuidString + ".json")
    }

    private static func testFileStore() throws {
        let root = temporaryRoot("bridge")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = TodoBridgePaths(homeDirectory: root)
        let store = TodoBridgeFileStore(paths: paths)
        let now = Date(timeIntervalSince1970: 1_760_000_000)

        check("a missing bridge reads no snapshot", try store.loadSnapshot() == nil)
        check("a missing bridge reads no status", try store.loadStatus() == nil)
        check("a missing status is offline", !store.isLive(now: now, maxAge: 10))
        check("a missing commands directory queues nothing", store.pendingCommandCount() == 0)

        let requestID = UUID()
        let payload = TodoBridgeTaskPayload(
            id: UUID(), title: "Created", startDate: nil, dueDate: nil, boardSectionID: nil,
            labelID: nil, subtasks: [])
        let command = TodoBridgeCommand(
            schemaVersion: 1, requestID: requestID, kind: .create, sentAt: now,
            task: payload, taskID: nil, isCompleted: nil)
        let commandURL = try store.writeCommand(command)
        check("a write creates the commands directory",
              FileManager.default.fileExists(atPath: commandURL.path))
        check("a written command is pending", store.pendingCommandCount() == 1)
        let commandData = try Data(contentsOf: commandURL)
        let written = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeCommand.self, from: commandData)
        check("the written file is the command", written == command)

        let commandsDirectory = paths.commandsDirectory
        try Data("x".utf8).write(
            to: commandsDirectory.appending(path: ".hidden.json", directoryHint: .notDirectory))
        try Data("x".utf8).write(
            to: commandsDirectory.appending(path: "notes.txt", directoryHint: .notDirectory))
        check("dotfiles and non-JSON entries are not pending", store.pendingCommandCount() == 1)

        var replacement = command
        replacement.kind = .update
        let overwriteURL = try store.writeCommand(replacement)
        check("the same request overwrites its file", overwriteURL == commandURL)
        check("an overwrite leaves one pending file", store.pendingCommandCount() == 1)
        let overwriteData = try Data(contentsOf: commandURL)
        let overwritten = try TodoBridgeProtocol.makeDecoder().decode(
            TodoBridgeCommand.self, from: overwriteData)
        check("an overwrite lands the last write", overwritten == replacement)

        let second = TodoBridgeCommand(
            schemaVersion: 1, requestID: UUID(), kind: .setCompleted,
            sentAt: now.addingTimeInterval(1), task: nil, taskID: UUID(), isCompleted: true)
        _ = try store.writeCommand(second)
        check("a distinct request queues beside the first", store.pendingCommandCount() == 2)

        try FileManager.default.createDirectory(
            at: paths.resultsDirectory, withIntermediateDirectories: true)
        let result = TodoBridgeResult(
            schemaVersion: 1, requestID: requestID, ok: true, completedAt: now, revision: 5,
            errorCode: nil, errorMessage: nil)
        try TodoBridgeProtocol.makeEncoder().encode(result).write(
            to: paths.resultsDirectory.appending(
                path: requestID.uuidString + ".json", directoryHint: .notDirectory),
            options: .atomic)
        check("a result written under the request id reads back",
              try store.loadResult(requestID: requestID) == result)
        check("an unanswered request has no result",
              try store.loadResult(requestID: UUID()) == nil)
        store.removeResult(requestID: requestID)
        check("removing a result clears it", try store.loadResult(requestID: requestID) == nil)
        store.removeResult(requestID: UUID())

        try FileManager.default.createDirectory(
            at: paths.baseURL, withIntermediateDirectories: true)
        let snapshot = TodoBridgeSnapshot(
            schemaVersion: 1, revision: 5, generatedAt: now, tasks: [], labels: [],
            boardSections: [])
        try TodoBridgeProtocol.makeEncoder().encode(snapshot).write(
            to: paths.snapshotURL, options: .atomic)
        check("a snapshot reads back", try store.loadSnapshot() == snapshot)
        let status = TodoBridgeStatus(
            schemaVersion: 1, pid: 7, startedAt: now, lastHeartbeatAt: now, revision: 5)
        try TodoBridgeProtocol.makeEncoder().encode(status).write(
            to: paths.statusURL, options: .atomic)
        check("a status reads back", try store.loadStatus() == status)

        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-5)], ofItemAtPath: paths.statusURL.path)
        check("a recent heartbeat is live", store.isLive(now: now, maxAge: 10))
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-30)], ofItemAtPath: paths.statusURL.path)
        check("a stale heartbeat is not live", !store.isLive(now: now, maxAge: 10))
    }

    // MARK: - Draft

    private static func testDraftPayloads() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let sectionID = UUID()
        let fresh = TodoEditorDraft.new(defaultSectionID: sectionID, now: now)
        check("a new draft is unsaved and undated",
              fresh.isNew && fresh.taskID == nil && !fresh.canSave && !fresh.hasDueDate
                && fresh.dueDate == now)
        check("a new draft lands in its default section",
              fresh.boardSectionID == sectionID && fresh.labelID == nil && fresh.subtasks.isEmpty)

        var titled = fresh
        titled.title = "  Buy milk  "
        check("a trimmed title saves", titled.canSave)
        titled.title = " \t "
        check("whitespace alone does not save", !titled.canSave)
        titled.title = "  Buy milk  "
        titled.hasDueDate = true
        titled.dueDate = now.addingTimeInterval(3600)
        titled.labelID = UUID()
        let createdID = UUID()
        let created = titled.createPayload(taskID: createdID)
        check("a create payload carries the caller's id and a trimmed title",
              created.id == createdID && created.title == "Buy milk")
        check("a create payload trims the title and carries the due date",
              created.dueDate == titled.dueDate && created.startDate == nil)
        check("a create payload carries section, label and subtasks",
              created.boardSectionID == sectionID && created.labelID == titled.labelID
                && created.subtasks.isEmpty)
        check("a new draft has no update payload", titled.updatePayload() == nil)

        titled.hasDueDate = false
        check("an off due date is omitted from the payload",
              titled.createPayload(taskID: UUID()).dueDate == nil)

        let subtask = TodoBridgeSubtask(id: UUID(), title: "skim", isCompleted: true)
        let existing = TodoBridgeTask(
            id: UUID(), title: "Stored", notes: "kept", notesMarkdown: "# kept",
            startDate: now, dueDate: now.addingTimeInterval(3600), bucket: .week,
            boardSectionID: nil, labelID: UUID(), isCompleted: false, subtasks: [subtask])
        var editing = TodoEditorDraft(task: existing)
        check("an edit draft is not new", !editing.isNew && editing.taskID == existing.id)
        check("an edit draft copies the stored fields",
              editing.title == "Stored" && editing.hasDueDate && editing.dueDate == existing.dueDate
                && editing.boardSectionID == nil && editing.labelID == existing.labelID
                && editing.subtasks == [subtask])
        let updated = try require(editing.updatePayload())
        check("an update payload keeps the task id",
              updated.id == existing.id && updated.title == "Stored")
        check("an update payload carries the due date and subtasks",
              updated.dueDate == existing.dueDate && updated.subtasks == [subtask])
        editing.title = "Renamed"
        editing.hasDueDate = false
        check("an update reflects the edit",
              editing.updatePayload()?.title == "Renamed"
                && editing.updatePayload()?.dueDate == nil)

        let undated = TodoBridgeTask(
            id: UUID(), title: "Undated", notes: "", notesMarkdown: nil, startDate: nil,
            dueDate: nil, bucket: .later, boardSectionID: nil, labelID: nil, isCompleted: false,
            subtasks: [])
        check("an undated task edits undated", !TodoEditorDraft(task: undated).hasDueDate)
    }

    private static func testDraftSubtaskEdits() {
        var draft = TodoEditorDraft.new(defaultSectionID: nil, now: Date(timeIntervalSince1970: 0))
        draft.addSubtask()
        draft.addSubtask()
        check(
            "adding subtasks appends empty incomplete rows",
            draft.subtasks.count == 2
                && draft.subtasks.allSatisfy { $0.title.isEmpty && !$0.isCompleted })
        let first = draft.subtasks[0].id
        let second = draft.subtasks[1].id
        draft.toggleSubtask(id: first)
        check("toggling flips one subtask",
              draft.subtasks[0].isCompleted && !draft.subtasks[1].isCompleted)
        draft.toggleSubtask(id: first)
        check("toggling again flips it back", !draft.subtasks[0].isCompleted)
        draft.toggleSubtask(id: UUID())
        check("toggling an unknown id is a no-op", draft.subtasks.count == 2)
        draft.removeSubtask(id: first)
        check("removing deletes only its row",
              draft.subtasks.map(\.id) == [second])
        draft.removeSubtask(id: UUID())
        check("removing an unknown id is a no-op", draft.subtasks.count == 1)
    }

    private static func testDraftNotesPayloads() throws {
        var draft = TodoEditorDraft.new(defaultSectionID: nil, now: Date(timeIntervalSince1970: 0))
        draft.title = "Task"
        draft.notesMarkdown = "  # Plan  "
        check("a create carries trimmed notes markdown",
              draft.createPayload(taskID: UUID()).notesMarkdown == "# Plan")
        draft.notesMarkdown = " \t "
        check("a create omits empty notes",
              draft.createPayload(taskID: UUID()).notesMarkdown == nil)

        let stored = TodoBridgeTask(
            id: UUID(), title: "Stored", notes: "# kept", notesMarkdown: "# kept",
            startDate: nil, dueDate: nil, bucket: .today, boardSectionID: nil, labelID: nil,
            isCompleted: false, subtasks: [])
        var editing = TodoEditorDraft(task: stored)
        let untouched = try require(editing.updatePayload())
        check("an update omits untouched notes", untouched.notesMarkdown == nil)
        editing.notesMarkdown = "  # edited  "
        let edited = try require(editing.updatePayload())
        check("an update sends trimmed edited notes", edited.notesMarkdown == "# edited")
        editing.notesMarkdown = ""
        let cleared = try require(editing.updatePayload())
        check("an update sends an empty clear", cleared.notesMarkdown == "")
    }

    private static func testDraftNotesSeeding() throws {
        let marked = TodoBridgeTask(
            id: UUID(), title: "Marked", notes: "plain", notesMarkdown: "# rich",
            startDate: nil, dueDate: nil, bucket: .today, boardSectionID: nil, labelID: nil,
            isCompleted: false, subtasks: [])
        let seeded = TodoEditorDraft(task: marked)
        check("an edit draft seeds from the stored markdown",
              seeded.notesMarkdown == "# rich" && seeded.initialNotesMarkdown == "# rich")

        let legacy = TodoBridgeTask(
            id: UUID(), title: "Legacy", notes: "rtf plain", notesMarkdown: nil,
            startDate: nil, dueDate: nil, bucket: .today, boardSectionID: nil, labelID: nil,
            isCompleted: false, subtasks: [])
        var editing = TodoEditorDraft(task: legacy)
        check("a legacy task seeds from its plain notes",
              editing.notesMarkdown == "rtf plain"
                && editing.initialNotesMarkdown == "rtf plain")
        check("a legacy task is left untouched until edited",
              try require(editing.updatePayload()).notesMarkdown == nil)
        editing.notesMarkdown = "rtf plain "
        check("editing a legacy task sends the trimmed notes",
              try require(editing.updatePayload()).notesMarkdown == "rtf plain")
    }

    // MARK: - List

    private static func testGrouping() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let calendar = fixedCalendar(offset: 0)
        let inboxID = UUID()
        let workID = UUID()
        let homeID = UUID()
        let unknownID = UUID()
        let inboxSection = TodoBridgeBoardSection(id: inboxID, name: "Inbox", isInbox: true)
        let workSection = TodoBridgeBoardSection(id: workID, name: "Work", isInbox: false)
        let homeSection = TodoBridgeBoardSection(id: homeID, name: "Home", isInbox: false)
        let labelID = UUID()
        let label = TodoBridgeLabel(id: labelID, name: "Errands", colorHex: "#FF0000")
        let snapshot = TodoBridgeSnapshot(
            schemaVersion: 1, revision: 1, generatedAt: now,
            tasks: [
                makeTask(title: "work-task", sectionID: workID),
                makeTask(title: "delta", dueDate: now.addingTimeInterval(-3600)),
                makeTask(title: "alpha", dueDate: now.addingTimeInterval(3600)),
                makeTask(title: "Charlie", labelID: labelID),
                makeTask(title: "stranger", sectionID: unknownID),
                makeTask(title: "done", isCompleted: true),
                makeTask(title: "home-done", sectionID: homeID, isCompleted: true)
            ],
            labels: [label],
            boardSections: [workSection, inboxSection, homeSection])
        let model = TodoListModel(snapshot: snapshot)

        let open = model.groups(includingCompleted: false, now: now, calendar: calendar)
        check("the inbox group leads despite snapshot order",
              open.map(\.id) == [inboxID.uuidString, workID.uuidString])
        check("a group carries its section identity",
              open[0].sectionID == inboxID && open[0].title == "Inbox"
                && open[1].sectionID == workID && open[1].title == "Work")
        check("empty groups are omitted", !open.contains { $0.id == homeID.uuidString })
        check("completed tasks hide", open.allSatisfy { group in
            group.tasks.allSatisfy { !$0.isCompleted }
        })
        check("undated and unknown-section tasks land in the inbox",
              open[0].tasks.map(\.title) == ["delta", "alpha", "Charlie", "stranger"])
        check("a section's own tasks stay in it",
              open[1].tasks.map(\.title) == ["work-task"])

        let all = model.groups(includingCompleted: true, now: now, calendar: calendar)
        check("completed tasks return when asked for",
              all[0].tasks.map(\.title) == ["delta", "alpha", "Charlie", "stranger", "done"]
                && all.contains {
                    $0.id == homeID.uuidString && $0.tasks.map(\.title) == ["home-done"]
                })
        check("completed tasks sort after incomplete ones",
              all[0].tasks.last?.isCompleted == true)

        let tieSnapshot = TodoBridgeSnapshot(
            schemaVersion: 1, revision: 1, generatedAt: now,
            tasks: [makeTask(title: "bravo"), makeTask(title: "Alpha")],
            labels: [],
            boardSections: [inboxSection])
        let tied = TodoListModel(snapshot: tieSnapshot)
            .groups(includingCompleted: true, now: now, calendar: calendar)
        check("titles break ties insensitively", tied[0].tasks.map(\.title) == ["Alpha", "bravo"])

        let bareSnapshot = TodoBridgeSnapshot(
            schemaVersion: 1, revision: 1, generatedAt: now,
            tasks: [makeTask(title: "loose")],
            labels: [],
            boardSections: [])
        let bare = TodoListModel(snapshot: bareSnapshot)
            .groups(includingCompleted: true, now: now, calendar: calendar)
        check("a snapshot without an inbox section still groups inbox tasks",
              bare.map(\.id) == [TodoListModel.inboxGroupID]
                && bare[0].sectionID == nil && bare[0].title == nil)

        let firstTask = try require(model.task(id: snapshot.tasks[0].id))
        check("a task looks up by id", firstTask.title == "work-task")
        check("a nil section id names the inbox", model.section(id: nil) == inboxSection)
        check("a section looks up by id", model.section(id: workID) == workSection)
        check("an unknown section is not invented", model.section(id: unknownID) == nil)
        check("labels look up by id", model.label(id: labelID) == label)
        check("a nil label id is no label", model.label(id: nil) == nil)
    }

    private static func testDueLabelBoundaries() throws {
        let tokyo = fixedCalendar(offset: 9 * 3600)
        let now = try isoDate("2026-10-19T16:00:00Z")   // Tokyo: Oct 20, 01:00
        let startOfToday = tokyo.startOfDay(for: now)
        let lastOfYesterday = startOfToday.addingTimeInterval(-1)
        let startOfTomorrow = try require(tokyo.date(byAdding: .day, value: 1, to: startOfToday))
        let lastOfToday = startOfTomorrow.addingTimeInterval(-1)
        let dayAfter = startOfTomorrow.addingTimeInterval(86400)
        check("the first instant of today is today",
              TodoListModel.dueLabel(for: startOfToday, now: now, calendar: tokyo) == .today)
        check("the last instant of yesterday is overdue",
              TodoListModel.dueLabel(for: lastOfYesterday, now: now, calendar: tokyo)
                == .overdue(lastOfYesterday))
        check("the last instant of today is today",
              TodoListModel.dueLabel(for: lastOfToday, now: now, calendar: tokyo) == .today)
        check("the first instant of tomorrow is tomorrow",
              TodoListModel.dueLabel(for: startOfTomorrow, now: now, calendar: tokyo) == .tomorrow)
        check("a later date keeps its date",
              TodoListModel.dueLabel(for: dayAfter, now: now, calendar: tokyo) == .date(dayAfter))
        check("no due date has no label",
              TodoListModel.dueLabel(for: nil, now: now, calendar: tokyo) == nil)

        let utc = fixedCalendar(offset: 0)
        let boundary = try isoDate("2026-10-19T10:00:00Z")
        check("the calendar decides: overdue in Tokyo, today in UTC",
              TodoListModel.dueLabel(for: boundary, now: now, calendar: tokyo) == .overdue(boundary)
                && TodoListModel.dueLabel(for: boundary, now: now, calendar: utc) == .today)
    }

    private static func testIsOverdue() {
        let calendar = fixedCalendar(offset: 0)
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let past = calendar.startOfDay(for: now).addingTimeInterval(-1)
        check("an incomplete task before today is overdue",
              TodoListModel.isOverdue(
                  task: makeTask(title: "open", dueDate: past), now: now, calendar: calendar))
        check("a task due today is not overdue",
              !TodoListModel.isOverdue(
                  task: makeTask(title: "today", dueDate: calendar.startOfDay(for: now)),
                  now: now, calendar: calendar))
        check("a completed task is never overdue",
              !TodoListModel.isOverdue(
                  task: makeTask(title: "done", dueDate: past, isCompleted: true),
                  now: now, calendar: calendar))
        check(
            "an undated task is never overdue",
            !TodoListModel.isOverdue(
                task: makeTask(title: "undated"), now: now, calendar: calendar))
    }

    private static func testSubtaskSummary() {
        let task = makeTask(title: "t", subtasks: [
            TodoBridgeSubtask(id: UUID(), title: "a", isCompleted: true),
            TodoBridgeSubtask(id: UUID(), title: "b", isCompleted: false),
            TodoBridgeSubtask(id: UUID(), title: "c", isCompleted: true)
        ])
        let summary = TodoListModel.subtaskSummary(task: task)
        check("the summary counts completed of total",
              summary.completed == 2 && summary.total == 3)
        let empty = TodoListModel.subtaskSummary(task: makeTask(title: "bare"))
        check("a task without subtasks summarises empty", empty.completed == 0 && empty.total == 0)
    }

    private static func testQueryMatching() {
        let task = makeTask(title: "Buy CAFÉ")
        check("a query matches the title without case", task.matches(query: "buy café"))
        check("a query folds diacritics", task.matches(query: "cafe"))
        check("an empty query matches everything", task.matches(query: ""))
        check("a non-matching query stays false", !task.matches(query: "milk"))
    }

    // MARK: - Fixtures

    private static func makeTask(
        title: String, dueDate: Date? = nil, sectionID: UUID? = nil, labelID: UUID? = nil,
        isCompleted: Bool = false, subtasks: [TodoBridgeSubtask] = []
    ) -> TodoBridgeTask {
        TodoBridgeTask(
            id: UUID(), title: title, notes: "", notesMarkdown: nil, startDate: nil,
            dueDate: dueDate, bucket: .today, boardSectionID: sectionID, labelID: labelID,
            isCompleted: isCompleted, subtasks: subtasks)
    }

    private static func fixedCalendar(offset: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: offset) ?? TimeZone.current
        return calendar
    }

    private static func isoDate(_ text: String) throws -> Date {
        try require(ISO8601DateFormatter().date(from: text))
    }

    private static func temporaryRoot(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "tinycast-todos-\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw TestFailure.missingValue }
        return value
    }

    private static func check(_ message: String, _ condition: @autoclosure () throws -> Bool) {
        do {
            if try condition() { return }
        } catch {
            print("FAIL: \(message) (\(error))")
            failures += 1
            return
        }
        print("FAIL: \(message)")
        failures += 1
    }
}

private enum TestFailure: Error {
    case missingValue
}
