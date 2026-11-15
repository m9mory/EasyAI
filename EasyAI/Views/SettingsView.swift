import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var showKeyEditor = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Подключение") {
                    Button {
                        showKeyEditor = true
                    } label: {
                        HStack {
                            Label("API-ключ", systemImage: "key")
                            Spacer()
                            Text(settings.hasKey ? "задан" : "не задан")
                                .foregroundStyle(settings.hasKey ? Color.secondary : Color.red)
                        }
                    }

                    HStack {
                        Text("Адрес API")
                        Spacer()
                        TextField("https://…", text: $settings.endpoint)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.footnote, design: .monospaced))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        Task { await store.refreshModels(settings: settings) }
                    } label: {
                        HStack {
                            Label("Проверить подключение", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if store.isRefreshingModels {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(store.isRefreshingModels || !settings.hasKey)
                }

                Section("Модель") {
                    Picker("Модель по умолчанию", selection: $settings.defaultModel) {
                        ForEach(store.modelChoices) { model in
                            Text(model.title).tag(model.id)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Температура")
                            Spacer()
                            Text(String(format: "%.1f", settings.temperature))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.temperature, in: 0...1.5, step: 0.1)
                    }

                    Toggle("Потоковый ответ", isOn: $settings.streamingEnabled)
                }

                Section("Поведение") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Системный промпт")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $settings.systemPrompt)
                            .frame(minHeight: 90)
                            .font(.footnote)
                    }
                }

                Section("Данные") {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Удалить всю историю чатов", systemImage: "trash")
                    }
                }

                Section {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("EasyAI — минимальный клиент. Ключ и переписка остаются на устройстве.")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showKeyEditor) {
                ApiKeyView(mode: .settings) {}
            }
            .confirmationDialog("Удалить все чаты?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Удалить всё", role: .destructive) {
                    store.clearAll()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Переписка будет удалена с этого устройства. Ключ останется.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
