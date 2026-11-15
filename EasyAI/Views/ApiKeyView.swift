import SwiftUI

/// API key entry — used on first launch and in settings.
struct ApiKeyView: View {
    enum Mode { case onboarding, settings }

    let mode: Mode
    var onSaved: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""
    @State private var isChecking = false
    @State private var errorText: String?
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    keyField
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                    actionButton
                    footer
                }
                .padding(22)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(mode == .onboarding ? "Вход" : "API-ключ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .settings {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                    }
                }
            }
        }
        .onAppear {
            draft = settings.apiKey
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("EasyAI")
                        .font(.largeTitle.weight(.bold))
                    Text("простой клиент для нейросети")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Вставь свой API-ключ. Он хранится в Keychain на устройстве и отправляется только на api.aikeysforyou.com.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API-ключ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Group {
                    if showKey {
                        TextField("sk-…", text: $draft)
                    } else {
                        SecureField("sk-…", text: $draft)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .onChange(of: draft) { _, _ in
                    errorText = nil
                }

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKey ? "Скрыть ключ" : "Показать ключ")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Label("Адрес API: \(settings.baseURL.absoluteString)", systemImage: "link")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var actionButton: some View {
        Button {
            Task { await verifyAndSave() }
        } label: {
            HStack(spacing: 8) {
                if isChecking {
                    ProgressView().controlSize(.small)
                }
                Text(isChecking ? "Проверяю ключ…" : "Продолжить")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
        .controlSize(.large)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ключ не уходит никуда, кроме выбранного API.")
            if settings.hasKey {
                Button(role: .destructive) {
                    settings.clearKey()
                    draft = ""
                    if mode == .settings { dismiss() }
                } label: {
                    Text("Удалить сохранённый ключ")
                        .font(.footnote)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func verifyAndSave() async {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isChecking = true
        errorText = nil
        defer { isChecking = false }

        let client = APIClient(apiKey: key, baseURL: settings.baseURL)
        do {
            _ = try await client.fetchModels()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorText = message
            return
        }

        settings.setKey(key)
        onSaved()
        if mode == .settings { dismiss() }
    }
}
