import SwiftUI

struct DeveloperToolView: View {
    let tool: UtilityTool

    var body: some View {
        Group {
            switch tool {
            case .urlCodec, .base64: EncodingToolView(tool: tool)
            case .uuid: UUIDToolView()
            case .hash: HashToolView()
            case .jwt: JWTToolView()
            case .textDiff: TextDiffToolView()
            case .json, .timestamp, .currency: EmptyView()
            }
        }
    }
}
