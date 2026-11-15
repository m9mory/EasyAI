import SwiftUI

/// Slide-over list of saved chats.
struct ChatListView: View {
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var pendingDelete: Conversation?
    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.newConversation(model: settings.defaultModel)
                        dismiss()
                    } label: {
                        Label("Новый чат", systemImage: "plus.bubble")
                    }
                }

                Section("Чаты") {
                    ForEach(store.sortedConversations) { conversation in
                        Button {
                            store.select(conversation.id)
                            dismiss()
                        } label: {
                            row(for: conversation)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(conversation.id)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = conversation
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            store.clearAll()
                            dismiss()
                        } label: {
                            Label("Удалить все чаты", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog(
                "Удалить это чат?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let pendingDelete { store.delete(pendingDelete.id) }
                    pendingDelete = nil
                }
                Button("Отмена", role: .cancel) { pendingDelete = nil }
            }
        }
    }

    private func row(for conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle(for: conversation))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if store.selectedID == conversation.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func subtitle(for conversation: Conversation) -> String {
        let count = conversation.messages.filter { $0.role == .user }.count
        let date = conversation.updatedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(conversation.model) · \(count) сообщ. · \(date)"
    }
}
