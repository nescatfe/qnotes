import SwiftUI
import Combine
import UIKit
import FirebaseFirestore

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
    @State private var shareButtonText = "Share"
    @State private var copyLinkText = "Copy Link"
    @State private var showMenu = false
    @State private var showPublicLinkCopiedNotification = false
    @State private var showContentCopiedNotification = false
    
    let onSave: (Note) -> Void
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        _note = State(initialValue: note)
        _editedContent = State(initialValue: note.content)
        self.onSave = onSave
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 20/255, green: 21/255, blue: 28/255) : Color.white
    }
    
    private var noteSize: Int {
        note.content.utf8.count
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
                        Menu {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isEditing = true
                                }
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: copyNoteContent) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if note.isPublic {
                                Button(action: handleMakePrivate) {
                                    Label("Make Private", systemImage: "lock")
                                }
                                
                                Button(action: copyPublicLink) {
                                    Label("Copy Link", systemImage: "link")
                                }
                            } else {
                                Button(action: handleShare) {
                                    Label(note.isPublic ? "Copy Public Link" : "Share", systemImage: note.isPublic ? "doc.on.doc" : "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(colorScheme == .dark ? .draculaPurple : .draculaPurple)
                        }
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
            
            if showPublicLinkCopiedNotification {
                publicLinkCopiedNotificationView
            }
            
            if showContentCopiedNotification {
                contentCopiedNotificationView
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
                
                Text("\(wordCount)w / \(note.content.count)c / \(formatSize(noteSize))")
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
    
    private var publicLinkCopiedNotificationView: some View {
        notificationView(text: "Public link copied to clipboard")
    }
    
    private var contentCopiedNotificationView: some View {
        notificationView(text: "Note content copied to clipboard")
    }
    
    private func notificationView(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.draculaGreen.opacity(0.8))
                .cornerRadius(10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .edgesIgnoringSafeArea(.all)
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
            note.isPublic = note.isPublic // Preserve the public status
            note.publicId = note.publicId // Preserve the public ID
            onSave(note)
            
            // Update the local note state
            self.note = note
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isEditing = false
                isSaving = false
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
            showContentCopiedNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showContentCopiedNotification = false
            }
        }
    }
    
    private func handleShare() {
        isSaving = true
        shareButtonText = "Sharing..."
        
        let publicId = generateShortId()
        let publicNoteRef = Firestore.firestore().collection("public_notes").document(publicId)
        
        publicNoteRef.setData([
            "content": note.content,
            "timestamp": Timestamp(date: note.timestamp),
            "userId": note.userId,
            "publicId": publicId
        ]) { error in
            DispatchQueue.main.async {
                self.isSaving = false
                if let error = error {
                    print("Error sharing note: \(error.localizedDescription)")
                    self.shareButtonText = "Share Failed"
                } else {
                    self.note.isPublic = true
                    self.note.publicId = publicId
                    self.onSave(self.note)  // Make sure this updates the note in Firestore as well
                    self.shareButtonText = "Shared"
                    
                    // Create the public note URL
                    let publicNoteURL = "https://quicknot.vercel.app/p/\(publicId)" // Replace with your actual URL scheme
                    
                    // Copy the URL to clipboard
                    UIPasteboard.general.string = publicNoteURL
                    
                    // Show a notification that the link has been copied
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showPublicLinkCopiedNotification = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showPublicLinkCopiedNotification = false
                        }
                    }
                }
            }
        }
    }
    
    private func handleMakePrivate() {
        guard let publicId = note.publicId else { return }
        
        isSaving = true
        shareButtonText = "Making Private..."
        
        let publicNoteRef = Firestore.firestore().collection("public_notes").document(publicId)
        
        publicNoteRef.delete { error in
            DispatchQueue.main.async {
                self.isSaving = false
                if let error = error {
                    print("Error making note private: \(error)")
                    self.shareButtonText = "Make Private Failed"
                } else {
                    self.note.isPublic = false
                    self.note.publicId = nil
                    self.onSave(self.note)  // Make sure this updates the note in Firestore as well
                    self.shareButtonText = "Share"
                }
            }
        }
    }
    
    private func generateShortId() -> String {
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
    
    private func copyPublicLink() {
        guard let publicId = note.publicId else { return }
        let link = "https://quicknot.vercel.app/p/\(publicId)"
        UIPasteboard.general.string = link
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showPublicLinkCopiedNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPublicLinkCopiedNotification = false
            }
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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