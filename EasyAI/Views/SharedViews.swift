import SwiftUI

/// Small shared UI pieces.

struct StreamingDots: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(opacity(for: index))
            }
        }
        .foregroundStyle(.secondary)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
        .accessibilityLabel("Печатает")
    }

    private func opacity(for index: Int) -> Double {
        let position = (phase + Double(index)).truncatingRemainder(dividingBy: 3)
        return 0.25 + (1 - min(abs(position - 1), 1)) * 0.75
    }
}

struct EmptyChatView: View {
    let onSuggestion: (String) -> Void

    private let suggestions = [
        "Объясни, как работает HTTP/2, простыми словами",
        "Сравни SwiftUI и UIKit для нового проекта",
        "Помоги придумать название для AI-приложения",
        "Напиши план обучения iOS-разработке на 3 месяца"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tint)
            Text("Чем помочь?")
                .font(.title2.weight(.semibold))
            Text("Сообщения хранятся только на этом устройстве, ключ — в Keychain.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        onSuggestion(text)
                    } label: {
                        HStack {
                            Text(text)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
    }
}
