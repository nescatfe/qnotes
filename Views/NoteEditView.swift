import SwiftUI
import Combine

struct NoteEditView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager: AuthenticationManager
    
    enum Mode {
        case add, edit
    }
    
    let mode: Mode
    let onSave: (Note) -> Void
    @State private var content: String
    @State private var animateContent = false
    @State private var showingCharacterCount = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var currentNote: Note?
    @State private var isKeyboardVisible = false
    
    init(authManager: AuthenticationManager, mode: Mode, content: String = "", existingNote: Note? = nil, onSave: @escaping (Note) -> Void) {
        self.authManager = authManager
        self.mode = mode
        self._content = State(initialValue: content)
        self.onSave = onSave
        self._currentNote = State(initialValue: existingNote)
    }
    
    // Add this computed property at the top level of the NoteEditView struct
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 20/255, green: 21/255, blue: 28/255) // Even darker background for dark mode
        } else {
            return Color.white // Normal white for light mode
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                if let note = currentNote, mode == .add {
                    NoteDetailView(note: note, onSave: onSave)
                } else {
                    TextEditor(text: $content)
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .padding()
                        .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                        .background(Color.clear)
                        .focused($isTextFieldFocused)
                    
                    bottomBar
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(mode == .add ? "New Note" : "Edit Note")
                    .font(.system(size: 17, weight: .regular, design: .monospaced))
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.3), value: animateContent)
        .onAppear {
            animateContent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(content.count) chars / \(wordCount) words")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
            
            Spacer()
            
            if isKeyboardVisible {
                hideKeyboardButton
            }
            
            Spacer()
            
            pasteButton
            
            Spacer()
            
            saveButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
    
    private var hideKeyboardButton: some View {
        Button(action: {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isKeyboardVisible = false
        }) {
            HStack(spacing: 4) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
                Text("Hide")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
        }
    }
    
    private var pasteButton: some View {
        Button(action: {
            if let pastedText = UIPasteboard.general.string {
                content += pastedText
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                Text("Paste")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(colorScheme == .dark ? .draculaPurple : .blue)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            if mode == .add {
                let newNote = Note(content: content.trimmingCharacters(in: .whitespacesAndNewlines), timestamp: Date(), userId: authManager.user?.uid ?? "")
                onSave(newNote)
                currentNote = newNote
            } else if let existingNote = currentNote {
                let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if existingNote.content != trimmedContent {
                    var updatedNote = existingNote
                    updatedNote.content = trimmedContent
                    updatedNote.timestamp = Date() // Only update timestamp if content changed
                    onSave(updatedNote)
                } else {
                    // If content hasn't changed, just call onSave with the existing note
                    onSave(existingNote)
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: mode == .add ? "square.and.arrow.down" : "checkmark")
                    .font(.system(size: 16))
                Text(mode == .add ? "Save" : "Done")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(content.isEmpty ? .gray : (colorScheme == .dark ? .draculaGreen : .blue))
        }
        .disabled(content.isEmpty)
    }
    
    private var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}