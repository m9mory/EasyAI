import SwiftUI

/// Renders markdown-ish assistant text with selectable content and copy support.
struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool

    @State private var showCopied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if let reasoning = message.reasoning, !reasoning.isEmpty {
                reasoningView(reasoning)
            }

            if !message.content.isEmpty {
                contentView
            } else if isStreaming {
                StreamingDots()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(bubbleBackground, in: bubbleShape)
            }

            if !isStreaming, !message.content.isEmpty {
                Button {
                    UIPasteboard.general.string = message.content
                    withAnimation { showCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        withAnimation { showCopied = false }
                    }
                } label: {
                    Label(showCopied ? "Скопировано" : "Копировать",
                          systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .tint(isUser ? Color.white.opacity(0.9) : Color.accentColor)
                .textSelection(.enabled)

            if isStreaming {
                StreamingDots()
                    .padding(.top, 8)
                    .opacity(isUser ? 0 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bubbleBackground, in: bubbleShape)
        .frame(maxWidth: 520, alignment: isUser ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func reasoningView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Размышления", systemImage: "brain")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: message.content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.content)
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    private var bubbleBackground: AnyShapeStyle {
        if isUser {
            return AnyShapeStyle(Color.accentColor.gradient)
        }
        return AnyShapeStyle(.fill.tertiary)
    }
}
