import Foundation

// MARK: - API Message
//
// Richer message representation that supports the full OpenAI chat completions
// shape — content strings, assistant messages with tool_calls, and tool result
// messages. The previous tuple-based `(role, content)` was sufficient for
// content-only chat but can't represent tool flows.

struct APIMessage {
    let role: Role
    let content: String?
    let toolCalls: [APIToolCall]?
    let toolCallId: String?

    enum Role: String {
        case system
        case user
        case assistant
        case tool
    }

    static func system(_ content: String) -> APIMessage {
        APIMessage(role: .system, content: content, toolCalls: nil, toolCallId: nil)
    }

    static func user(_ content: String) -> APIMessage {
        APIMessage(role: .user, content: content, toolCalls: nil, toolCallId: nil)
    }

    static func assistant(_ content: String) -> APIMessage {
        APIMessage(role: .assistant, content: content, toolCalls: nil, toolCallId: nil)
    }

    static func assistantWithToolCalls(content: String?, toolCalls: [APIToolCall]) -> APIMessage {
        APIMessage(role: .assistant, content: content, toolCalls: toolCalls, toolCallId: nil)
    }

    static func toolResult(_ content: String, callId: String) -> APIMessage {
        APIMessage(role: .tool, content: content, toolCalls: nil, toolCallId: callId)
    }

    /// Serializes the message to a dictionary suitable for JSONSerialization.
    /// Matches OpenAI's chat completions message schema exactly.
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = ["role": role.rawValue]
        if let content {
            dict["content"] = content
        } else if role == .assistant {
            // OpenAI requires content to be present (even if null) on assistant
            // messages — represent it as NSNull so JSONSerialization keeps it.
            dict["content"] = NSNull()
        }
        if let toolCalls, !toolCalls.isEmpty {
            dict["tool_calls"] = toolCalls.map { $0.toJSON() }
        }
        if let toolCallId {
            dict["tool_call_id"] = toolCallId
        }
        return dict
    }
}

// MARK: - Tool Call
//
// A single function invocation produced by the model. The model emits these
// inside its assistant message; the client executes them and replies with a
// tool result message keyed on `id`.

struct APIToolCall {
    let id: String
    let name: String
    /// JSON-encoded argument string. Always a string per OpenAI's schema —
    /// the client decodes it into typed values.
    let arguments: String

    func toJSON() -> [String: Any] {
        return [
            "id": id,
            "type": "function",
            "function": [
                "name": name,
                "arguments": arguments,
            ],
        ]
    }
}

// MARK: - Tool Definition
//
// Schema definition handed to OpenAI so the model knows what tools exist.
// JSON Schema for parameters per OpenAI's function calling spec.

struct ToolDefinition {
    let name: String
    let description: String
    let parameters: [String: Any]

    func toJSON() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters,
            ],
        ]
    }
}
