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