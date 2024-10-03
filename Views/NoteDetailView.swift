import SwiftUI
import Combine
// Import any other necessary modules

struct NoteDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var note: Note
    @State private var editedContent: String
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showCopiedNotification = false
    @State private var isLoading = true
    @State private var animateContent = false
    @State private var contentChunks: [String] = []
    @State private var showingUnsavedChangesAlert = false
    @State private var showingInfoAlert = false
    
    let onSave: (Note) -> Void
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        _note = State(initialValue: note)
        _editedContent = State(initialValue: note.content)
        self.onSave = onSave
    }
    
    // Add this computed property at the top level of the NoteDetailView struct
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 20/255, green: 21/255, blue: 28/255) // Even darker background for dark mode
        } else {
            return Color.white // Normal white for light mode
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .draculaForeground : .primary))
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEditing {
                    NoteEditView(authManager: AuthenticationManager(), mode: .edit, content: editedContent, existingNote: note) { updatedNote in
                        if updatedNote.content != self.note.content {
                            self.note = updatedNote
                            self.editedContent = updatedNote.content
                            self.onSave(updatedNote)
                        }
                        self.isEditing = false
                        self.loadNoteContent()
                    }
                } else {
                    noteContentView
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Note")
                        .font(.system(size: 17, weight: .regular, design: .monospaced))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isEditing {
                        infoButton
                    }
                }
            }
            .onDisappear {
                if isEditing {
                    showUnsavedChangesAlert()
                }
            }
            .onAppear {
                loadNoteContent()
            }
            
            if showCopiedNotification {
                copiedNotificationView
            }
        }
        .onChange(of: note) { _, _ in
            loadNoteContent()
        }
        .alert(isPresented: $showingUnsavedChangesAlert) {
            unsavedChangesAlert
        }
        .alert(isPresented: $showingInfoAlert) {
            infoAlert
        }
    }
    
    private var noteContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(formatDate(note.timestamp))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                    
                    Spacer()
                    
                    Text("\(wordCount)w / \(note.content.count)c")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                }
                .padding(.horizontal)
                
                ForEach(contentChunks.indices, id: \.self) { index in
                    Text(contentChunks[index])
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .padding(.horizontal)
                        .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                }
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isEditing = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            copyNoteContent()
        }
    }
    
    private var copiedNotificationView: some View {
        VStack {
            Spacer()
            Text("Copied")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .padding()
                .background(Color.draculaGreen)
                .foregroundColor(.draculaBackground)
                .cornerRadius(10)
            Spacer()
        }
        .transition(.opacity)
        .zIndex(1)
    }
    
    private var unsavedChangesAlert: Alert {
        Alert(
            title: Text("Unsaved Changes"),
            message: Text("You have unsaved changes. Do you want to save them?"),
            primaryButton: .default(Text("Save")) {
                saveNote()
                navigateBack()
            },
            secondaryButton: .destructive(Text("Discard")) {
                navigateBack()
            }
        )
    }
    
    private var infoAlert: Alert {
        Alert(
            title: Text("Gesture Guide"),
            message: Text("• Double tap to edit the note\n• Long press to copy the entire note"),
            dismissButton: .default(Text("Got it!"))
        )
    }
    
    private func loadNoteContent() {
        DispatchQueue.global(qos: .userInitiated).async {
            let content = self.note.content
            let chunkSize = 1000 // Adjust this value based on performance
            self.contentChunks = stride(from: 0, to: content.count, by: chunkSize).map {
                let startIndex = content.index(content.startIndex, offsetBy: $0)
                let endIndex = content.index(startIndex, offsetBy: min(chunkSize, content.count - $0))
                return String(content[startIndex..<endIndex])
            }
            
            DispatchQueue.main.async {
                self.editedContent = content
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isLoading = false
                    self.animateContent = true
                }
            }
        }
    }
    
    private func saveNote() {
        guard !isSaving else { return }
        isSaving = true
        
        if note.content != editedContent {
            note.content = editedContent
            note.timestamp = Date()
            onSave(note)
            
            // Update the local note state
            self.note = note
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isEditing = false
                isSaving = false
                loadNoteContent() // Reload content to reflect changes
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy / HH:mm"
        return formatter.string(from: date)
    }
    
    private var wordCount: Int {
        editedContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    private func showUnsavedChangesAlert() {
        showingUnsavedChangesAlert = true
    }
    
    private func navigateBack() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private var infoButton: some View {
        Button(action: {
            showingInfoAlert = true
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundColor(colorScheme == .dark ? .draculaPurple : .draculaPurple)
        }
    }
    
    private func copyNoteContent() {
        UIPasteboard.general.string = note.content
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedNotification = false
            }
        }
    }
}

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