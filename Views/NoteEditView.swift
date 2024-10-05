import SwiftUI
import Combine
import UIKit

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
    @State private var currentNote: Note?
    @State private var isContentValid: Bool = false
    @State private var isSaving: Bool = false
    
    init(authManager: AuthenticationManager, mode: Mode, content: String = "", existingNote: Note? = nil, onSave: @escaping (Note) -> Void) {
        self.authManager = authManager
        self.mode = mode
        self._content = State(initialValue: content)
        self.onSave = onSave
        self._currentNote = State(initialValue: existingNote)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 20/255, green: 21/255, blue: 28/255) : Color.white
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                SimpleLargeTextEditor(text: $content, isContentValid: $isContentValid)
                    .padding()
                
                saveButton
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(mode == .add ? "New Note" : "Edit Note")
                    .font(.system(size: 17, weight: .regular, design: .monospaced))
            }
        }
        .overlay(
            Group {
                if isSaving {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                }
            }
        )
    }
    
    private var saveButton: some View {
        Button(action: {
            if mode == .add {
                createNewNote()
            } else {
                editExistingNote()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: mode == .add ? "square.and.arrow.down" : "checkmark")
                    .font(.system(size: 16))
                Text(mode == .add ? "Save" : "Done")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
            .foregroundColor(isContentValid ? (colorScheme == .dark ? .draculaGreen : .blue) : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isContentValid ? (colorScheme == .dark ? .draculaGreen.opacity(0.2) : .blue.opacity(0.1)) : Color.gray.opacity(0.1))
            )
        }
        .disabled(!isContentValid || isSaving)
    }
    
    private func createNewNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            isSaving = true
            DispatchQueue.global(qos: .userInitiated).async {
                let newNote = Note(content: trimmedContent, timestamp: Date(), userId: authManager.user?.uid ?? "")
                
                DispatchQueue.main.async {
                    onSave(newNote)
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func editExistingNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty, let existingNote = currentNote {
            isSaving = true
            DispatchQueue.global(qos: .userInitiated).async {
                let updatedNote = Note(id: existingNote.id, content: trimmedContent, timestamp: Date(), isPinned: existingNote.isPinned, userId: existingNote.userId, syncState: .notSynced)
                
                DispatchQueue.main.async {
                    onSave(updatedNote)
                    isSaving = false
                    self.content = trimmedContent
                    self.currentNote = updatedNote
                }
            }
        }
    }
}

struct SimpleLargeTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isContentValid: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator
        
        // Optimize for large content
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.layoutManager.usesFontLeading = false
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
        // Disable unnecessary features for better performance
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            uiView.selectedRange = selectedRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SimpleLargeTextEditor
        var debounceTimer: Timer?
        
        init(_ parent: SimpleLargeTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                self.parent.text = textView.text
                self.updateContentValidity(textView)
            }
        }
        
        func updateContentValidity(_ textView: UITextView) {
            let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.parent.isContentValid = !trimmedText.isEmpty
            }
        }
    }
}
