//
//  Components.swift
//  Qnote
//
//  Created by coolskyz on 03/10/24.
//
import SwiftUI

// Define Dracula theme colors
extension Color {
    static let draculaBackground = Color(red: 40/255, green: 42/255, blue: 54/255)
    static let draculaForeground = Color(red: 248/255, green: 248/255, blue: 242/255)
    static let draculaComment = Color(red: 98/255, green: 114/255, blue: 164/255)
    static let draculaPurple = Color(red: 189/255, green: 147/255, blue: 249/255)
    static let draculaGreen = Color(red: 80/255, green: 250/255, blue: 123/255)
    static let draculaPink = Color(red: 255/255, green: 121/255, blue: 198/255)
    static let draculaYellow = Color(red: 241/255, green: 250/255, blue: 140/255)
}

// Add this extension to handle UserDefaults
extension UserDefaults {
    static let deletedNoteIdsKey = "deletedNoteIds"
    
    func deletedNoteIds() -> Set<String> {
        let array = array(forKey: UserDefaults.deletedNoteIdsKey) as? [String] ?? []
        return Set(array)
    }
    
    func setDeletedNoteIds(_ ids: Set<String>) {
        set(Array(ids), forKey: UserDefaults.deletedNoteIdsKey)
    }
}

// Make Note conform to Hashable
enum SyncState {
    case notSynced
    case syncing
    case synced
}

struct Note: Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var content: String
    var timestamp: Date
    var isPinned: Bool = false
    var userId: String
    var syncState: SyncState = .notSynced
    var needsSync: Bool = true

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CDNote {
    func toNote() -> Note {
        Note(id: self.id ?? UUID().uuidString,
             content: self.content ?? "",
             timestamp: self.timestamp ?? Date(),
             isPinned: self.isPinned,
             userId: self.userId ?? "",
             syncState: self.syncStateEnum)
    }
}

struct NoteRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let note: Note
    
    var body: some View {
        HStack(spacing: 12) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.draculaYellow)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .lineLimit(2)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                HStack {
                    Text(formatDate(note.timestamp))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                    syncStatusView
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var syncStatusView: some View {
        Text(syncStatusText)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundColor(syncStatusColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(syncStatusColor.opacity(0.2))
            )
    }
    
    private var syncStatusText: String {
        switch note.syncState {
        case .notSynced:
            return "Not synced"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        }
    }
    
    private var syncStatusColor: Color {
        switch note.syncState {
        case .notSynced:
            return .draculaPink
        case .syncing:
            return .draculaYellow
        case .synced:
            return .draculaGreen
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy / HH:mm"
        return formatter.string(from: date)
    }
}


