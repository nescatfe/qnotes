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
                if let note = currentNote, mode == .add {
                    NoteDetailView(note: note, onSave: onSave)
                } else {
                    SimpleLargeTextEditor(text: $content)
                        .padding()
                    
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
    }
    
    private var bottomBar: some View {
        HStack {
            Spacer()
            pasteButton
            Spacer()
            saveButton
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
                    updatedNote.timestamp = Date()
                    onSave(updatedNote)
                } else {
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
}

struct SimpleLargeTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SimpleLargeTextEditor
        
        init(_ parent: SimpleLargeTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}