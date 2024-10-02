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
    
    let onSave: (Note) -> Void
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        _note = State(initialValue: note)
        _editedContent = State(initialValue: note.content)
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            colorScheme == .dark ? Color.draculaBackground.ignoresSafeArea() : Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .draculaForeground : .primary))
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEditing {
                    VStack(spacing: 0) {
                        TextEditor(text: $editedContent)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                            .transition(.opacity)
                        
                        bottomBar
                    }
                } else {
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
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Note")
                        .font(.system(size: 17, weight: .regular, design: .monospaced))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            cancelButton
                        } else {
                            copyButton
                        }
                        editButton
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
        }
        .onChange(of: note) { _, _ in
            loadNoteContent()
        }
        .alert(isPresented: $showingUnsavedChangesAlert) {
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
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(editedContent.count) chars / \(wordCount) words")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
            
            Spacer()
            
            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }) {
                Text("Hide Keyboard")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
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
    
    private var editButton: some View {
        Button(isEditing ? "Save" : "Edit") {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isEditing {
                    saveNote()
                } else {
                    isEditing = true
                }
            }
        }
        .disabled(isEditing && isSaving)
        .foregroundColor(colorScheme == .dark ? .draculaGreen : .blue)
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private var copyButton: some View {
        Button(action: {
            UIPasteboard.general.string = note.content
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedNotification = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCopiedNotification = false
                }
            }
        }) {
            Text("Copy")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
        }
        .foregroundColor(colorScheme == .dark ? .draculaPurple : .blue)
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
    
    private var cancelButton: some View {
        Button(action: {
            if editedContent != note.content {
                showUnsavedChangesAlert()
            } else {
                cancelEdit()
            }
        }) {
            Text("Cancel")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
        }
        .foregroundColor(colorScheme == .dark ? .draculaPink : .red)
    }
    
    private func cancelEdit() {
        withAnimation {
            isEditing = false
            editedContent = note.content
        }
    }
    
    private func showUnsavedChangesAlert() {
        showingUnsavedChangesAlert = true
    }
    
    private func navigateBack() {
        presentationMode.wrappedValue.dismiss()
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
    
    init(authManager: AuthenticationManager, mode: Mode, content: String = "", onSave: @escaping (Note) -> Void) {
        self.authManager = authManager
        self.mode = mode
        self._content = State(initialValue: content)
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                topBar
                
                TextEditor(text: $content)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .padding()
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                    .background(Color.clear)
                    .focused($isTextFieldFocused)
                
                bottomBar
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
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.draculaBackground : Color(.systemBackground)
    }
    
    private var topBar: some View {
        HStack {
            pasteButton
            Spacer()
            saveButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(content.count) chars / \(wordCount) words")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
            
            Spacer()
            
            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }) {
                Text("Hide Keyboard")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
    
    private var pasteButton: some View {
        Button(action: {
            if let pastedText = UIPasteboard.general.string {
                content += pastedText
            }
        }) {
            HStack {
                Image("paste_button")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30) // Increased from 24
                Text("Paste")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(colorScheme == .dark ? Color.draculaPurple : Color.blue)
        .cornerRadius(8)
    }
    
    private var saveButton: some View {
        Button(action: {
            let newNote = Note(content: content.trimmingCharacters(in: .whitespacesAndNewlines), timestamp: Date(), userId: authManager.user?.uid ?? "")
            onSave(newNote)
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image("save_button")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30) // Increased from 24
                Text("Save")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(content.isEmpty ? Color.gray.opacity(0.5) : (colorScheme == .dark ? Color.draculaGreen : Color.blue))
        .cornerRadius(8)
        .disabled(content.isEmpty)
    }
    
    private var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}