import SwiftUI
import Combine
import UIKit

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
    @State private var showingUnsavedChangesAlert = false
    @State private var showingInfoAlert = false
    
    let onSave: (Note) -> Void
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        _note = State(initialValue: note)
        _editedContent = State(initialValue: note.content)
        self.onSave = onSave
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 20/255, green: 21/255, blue: 28/255) : Color.white
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
                        self.note = updatedNote
                        self.editedContent = updatedNote.content
                        self.onSave(updatedNote)
                        self.isEditing = false
                        // No need to call loadNoteContent() here as we're staying on the same view
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !isEditing {
                        editButton
                        copyButton
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
        VStack(spacing: 16) {
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
            
            EfficientTextView(text: note.content, textColor: colorScheme == .dark ? .draculaForeground : .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
    }
    
    private var editButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isEditing = true
            }
        }) {
            Text("Edit")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaPurple : .draculaPurple)
        }
    }
    
    private var copyButton: some View {
        Button(action: {
            copyNoteContent()
        }) {
            Text("Copy")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaPurple : .draculaPurple)
        }
    }
    
    private var copiedNotificationView: some View {
        VStack {
            Spacer()
            Text("All Content Copied")
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
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let content = self.note.content
            
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
                // No need to call loadNoteContent() here as we're staying on the same view
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

struct EfficientTextView: UIViewRepresentable {
    let text: String
    let textColor: Color
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = UIColor(textColor)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        // Optimize for large content
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.textContainer.lineFragmentPadding = 0
        textView.layoutManager.usesFontLeading = false
        
        // Disable unnecessary features for better performance
        textView.dataDetectorTypes = []
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.textColor = UIColor(textColor)
            uiView.setContentOffset(.zero, animated: false)
        }
    }
}