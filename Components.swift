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
    static let draculaOrange = Color(red: 255/255, green: 184/255, blue: 108/255) // Add this line
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
    let isRefreshing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.content.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines))
                .lineLimit(2)
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
            
            HStack(spacing: 8) {
                Text(formatDate(note.timestamp))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                syncStatusView
                if note.isPinned {
                    pinnedIndicator
                }
                Spacer()
            }
        }
        .padding(16)
        .background(noteBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(note.isPinned ? pinnedBorderColor : Color.gray.opacity(0.2), lineWidth: note.isPinned ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    private var noteBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(note.isPinned ? 
                  (colorScheme == .dark ? Color.draculaBackground.opacity(0.3) : Color.draculaOrange.opacity(0.1)) : 
                  (colorScheme == .dark ? Color.draculaBackground.opacity(0.1) : Color.white))
    }
    
    private var pinnedBorderColor: Color {
        colorScheme == .dark ? .draculaOrange : .draculaOrange.opacity(0.6)
    }
    
    private var pinnedIndicator: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 12))
            .foregroundColor(.draculaOrange)
    }
    
    private var syncStatusView: some View {
        Image(systemName: syncStatusSymbol)
            .foregroundColor(syncStatusColor)
            .font(.system(size: 12))
            .modifier(PulseAnimation(isPulsing: isRefreshing))
    }
    
    private var syncStatusSymbol: String {
        switch note.syncState {
        case .notSynced: return "iphone"
        case .syncing: return "arrow.2.circlepath"
        case .synced: return "icloud"
        }
    }
    
    private var syncStatusColor: Color {
        switch note.syncState {
        case .notSynced: return .draculaPink
        case .syncing: return .draculaYellow
        case .synced: return .draculaGreen
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        DateFormatter.noteListFormatter.string(from: date)
    }
}

// Add this extension at the end of the file
extension DateFormatter {
    static let noteListFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy / HH:mm"
        return formatter
    }()
}

struct PulseAnimation: ViewModifier {
    let isPulsing: Bool
    
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .animation(animation, value: isPulsing)
            .onAppear {
                if isPulsing {
                    withAnimation(animation.repeatForever()) {
                        scale = 1.2
                    }
                }
            }
            .onChange(of: isPulsing) { _, newValue in
                if newValue {
                    withAnimation(animation.repeatForever()) {
                        scale = 1.2
                    }
                } else {
                    withAnimation(animation) {
                        scale = 1.0
                    }
                }
            }
    }
    
    private var animation: Animation {
        Animation.easeInOut(duration: 0.5)
    }
}

// Add this new view for the search bar
struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var performSearch: () -> Void
    var clearSearch: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search notes", text: $searchText)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                    .accentColor(.draculaPurple)
                    .onSubmit(performSearch)
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(colorScheme == .dark ? Color.draculaBackground.opacity(0.3) : Color(.systemGray6))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.draculaPurple.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.8))
        .animation(.easeInOut, value: searchText)
    }
}