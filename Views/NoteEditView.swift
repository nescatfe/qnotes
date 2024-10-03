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
            saveNote()
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
    
    private func saveNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            isSaving = true
            DispatchQueue.global(qos: .userInitiated).async {
                let newNote: Note
                if mode == .add {
                    newNote = Note(content: trimmedContent, timestamp: Date(), userId: authManager.user?.uid ?? "")
                } else if let existingNote = currentNote {
                    newNote = Note(id: existingNote.id, content: trimmedContent, timestamp: Date(), isPinned: existingNote.isPinned, userId: existingNote.userId, syncState: .notSynced)
                } else {
                    return
                }
                
                DispatchQueue.main.async {
                    onSave(newNote)
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
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
        
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.layoutManager.usesFontLeading = false
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
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
        private var debounceWorkItem: DispatchWorkItem?
        
        init(_ parent: SimpleLargeTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            debounceWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.parent.text = textView.text
                self?.updateContentValidity(textView)
            }
            
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
        
        func updateContentValidity(_ textView: UITextView) {
            let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.parent.isContentValid = !trimmedText.isEmpty
            }
        }
    }
}
