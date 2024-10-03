//
//  ContentView.swift
//  Qnote
//
//  Created by coolskyz on 01/10/24.
// oh shittt

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreData
import Network
import Combine
import SDWebImageSwiftUI

class ConnectivityManager: ObservableObject {
    @Published var isConnected = false
    private let monitor = NWPathMonitor()
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView().environment(\.managedObjectContext, context)
            .environmentObject(AuthenticationManager())
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var connectivityManager = ConnectivityManager()
    @State private var notes: [Note] = []
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var noteToDelete: Note?
    @State private var animateList = false
    @State private var isAddingNewNote = false
    @State private var showingSettings = false
    @State private var showingLogoutConfirmation = false
    @State private var isLoggingOut = false
    @State private var deletedNoteIds: Set<String> = UserDefaults.standard.deletedNoteIds()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isRefreshing = false
    @State private var userProfileImageURL: URL?
    @State private var isCreatingNoteFromClipboard = false
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var hasMoreNotes = true
    private let notesPerPage = 20
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedView
            } else {
                LoginView()
            }
        }
        .onChange(of: connectivityManager.isConnected) { _, newValue in
            if newValue {
                syncPendingChanges()
            }
        }
        .onAppear {
            setupDeletedNoteIdsObserver()
            checkForUnpinnedNotesDeletion()
        }
    }
    
    private var authenticatedView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                notesList
            }
            .navigationTitle("Qnote")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    userProfileButton
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    pasteButton
                    refreshButton
                    addButton
                }
            }
            .background(backgroundColor)
            .navigationDestination(isPresented: $isAddingNewNote) {
                NoteEditView(authManager: authManager, mode: .add) { newNote in
                    addNote(newNote)
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note, onSave: updateNote)
            }
        }
        .environment(\.font, .system(.body, design: .monospaced))
        .tint(colorScheme == .dark ? .draculaForeground : .primary)
        .onAppear(perform: onAuthenticatedAppear)
        .alert(isPresented: $showingDeleteConfirmation, content: deleteConfirmationAlert)
        .confirmationDialog("Are you sure you want to log out?", isPresented: $showingLogoutConfirmation, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                logout()
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(loggingOutOverlay)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(showingLogoutConfirmation: $showingLogoutConfirmation, connectivityManager: connectivityManager, notes: $notes)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $isCreatingNoteFromClipboard) {
            if let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty {
                NoteEditView(authManager: authManager, mode: .add, content: clipboardContent) { newNote in
                    addNote(newNote)
                }
            }
        }
    }
    
    private func onAuthenticatedAppear() {
        setNavigationBarFont()
        fetchNotes()
        withAnimation(.easeOut(duration: 0.3)) {
            animateList = true
        }
        loadUserProfileImageURL()
    }
    
    private var loggingOutOverlay: some View {
        Group {
            if isLoggingOut {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
    }
    
    private func deleteConfirmationAlert() -> Alert {
        Alert(
            title: Text("Delete Note"),
            message: Text("Are you sure you want to delete this note?"),
            primaryButton: .destructive(Text("Delete")) {
                confirmDelete()
            },
            secondaryButton: .cancel()
        )
    }
    
    private var searchBar: some View {
        HStack {
            TextField("Search notes", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .padding(10)
                .background(colorScheme == .dark ? Color.draculaComment.opacity(0.3) : Color(.systemGray6))
                .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                .cornerRadius(8)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                }
                .padding(.trailing, 8)
                .transition(.opacity)
                .animation(.easeInOut, value: searchText)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var notesList: some View {
        Group {
            if notes.isEmpty {
                emptyNotesView
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note)
                        }
                        .listRowBackground(backgroundColor)
                        .swipeActions(edge: .trailing) {
                            if !note.isPinned {
                                Button(role: .destructive) {
                                    noteToDelete = note
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.draculaPink)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button(action: {
                                togglePin(note)
                            }) {
                                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.draculaYellow)
                        }
                    }
                    
                    if hasMoreNotes {
                        ProgressView()
                            .onAppear {
                                loadMoreNotes()
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyNotesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.draculaComment)
            
            Text("No Notes Yet")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
            
            Text("Tap 'Create New' to add your first note")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.draculaComment)
                .multilineTextAlignment(.center)
            
            Button(action: { isAddingNewNote = true }) {
                Text("Create New Note")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.draculaGreen)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }
    
    private var addButton: some View {
        Button(action: { isAddingNewNote = true }) {
            Text("Create New")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .draculaGreen : .blue)
        }
    }
    
    private var filteredNotes: [Note] {
        if notes.isEmpty {
            return []
        }
        let sorted = notes.sorted { 
            if $0.isPinned == $1.isPinned {
                return $0.timestamp > $1.timestamp
            }
            return $0.isPinned && !$1.isPinned
        }
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.content.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    private func fetchNotes() {
        isLoading = true
        currentPage = 1
        hasMoreNotes = true
        
        if connectivityManager.isConnected {
            fetchNotesFromFirebase(page: currentPage)
        } else {
            fetchNotesFromCoreData(page: currentPage)
        }
    }
    
    private func loadMoreNotes() {
        guard !isLoading && hasMoreNotes else { return }
        currentPage += 1
        
        if connectivityManager.isConnected {
            fetchNotesFromFirebase(page: currentPage)
        } else {
            fetchNotesFromCoreData(page: currentPage)
        }
    }
    
    private func fetchNotesFromFirebase(page: Int) {
        guard let userId = authManager.user?.uid else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        let notesRef = db.collection("users").document(userId).collection("notes")
        
        notesRef
            .order(by: "timestamp", descending: true)
            .limit(to: notesPerPage * page)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching documents: \(error)")
                    isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents")
                    isLoading = false
                    return
                }
                
                let fetchedNotes = documents.compactMap { document -> Note? in
                    let data = document.data()
                    guard let content = data["content"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                          let isPinned = data["isPinned"] as? Bool else {
                        return nil
                    }
                    return Note(id: document.documentID, content: content, timestamp: timestamp, isPinned: isPinned, userId: userId)
                }
                
                DispatchQueue.main.async {
                    if page == 1 {
                        self.notes = fetchedNotes
                    } else {
                        self.notes.append(contentsOf: fetchedNotes)
                    }
                    self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
                    self.isLoading = false
                    self.syncNotesToCoreData(fetchedNotes)
                }
            }
    }
    
    private func fetchNotesFromCoreData(page: Int) {
        guard let userId = authManager.user?.uid else { return }
        isLoading = true
        
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.timestamp, ascending: false)]
        fetchRequest.fetchLimit = notesPerPage
        fetchRequest.fetchOffset = (page - 1) * notesPerPage
        
        do {
            let cdNotes = try viewContext.fetch(fetchRequest)
            let fetchedNotes = cdNotes.map { $0.toNote() }
            
            DispatchQueue.main.async {
                if page == 1 {
                    self.notes = fetchedNotes
                } else {
                    self.notes.append(contentsOf: fetchedNotes)
                }
                self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
                self.isLoading = false
            }
        } catch {
            print("Error fetching notes from Core Data: \(error)")
            isLoading = false
        }
    }
    
    private func addNote(_ note: Note) {
        guard let userId = authManager.user?.uid else { return }
        var trimmedNote = note
        trimmedNote.content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmedNote.userId = userId  // Add this line
        
        // Add to local Core Data
        let newNote = CDNote(context: viewContext)
        newNote.id = trimmedNote.id
        newNote.userId = userId
        newNote.content = trimmedNote.content
        newNote.timestamp = trimmedNote.timestamp
        newNote.isPinned = trimmedNote.isPinned
        newNote.needsSync = true
        
        do {
            try viewContext.save()
            notes.append(trimmedNote)
        } catch {
            print("Error saving note to Core Data: \(error)")
        }
        
        // If online, sync to Firebase
        if connectivityManager.isConnected {
            syncNoteToFirebase(trimmedNote)
        }
    }
    
    private func syncNoteToFirebase(_ note: Note) {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("notes").document(note.id).setData([
            "content": note.content,
            "timestamp": Timestamp(date: note.timestamp),
            "isPinned": note.isPinned
        ]) { error in
            if let error = error {
                print("Error syncing note to Firebase: \(error.localizedDescription)")
            } else {
                // Mark as synced in Core Data
                let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@ AND userId == %@", note.id, userId)
                
                do {
                    let results = try viewContext.fetch(fetchRequest)
                    if let existingNote = results.first {
                        existingNote.needsSync = false
                        try viewContext.save()
                    }
                } catch {
                    print("Error marking note as synced in Core Data: \(error)")
                }
            }
        }
    }
    
    private func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            notes[index] = updatedNote
        }
        
        // Update in Core Data
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", updatedNote.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existingNote = results.first {
                existingNote.content = updatedNote.content
                existingNote.timestamp = updatedNote.timestamp
                existingNote.isPinned = updatedNote.isPinned
                existingNote.needsSync = true
                try viewContext.save()
            }
        } catch {
            print("Error updating note in Core Data: \(error)")
        }
        
        // If online, sync to Firebase
        if connectivityManager.isConnected {
            syncNoteToFirebase(updatedNote)
        }
    }
    
    private func deleteNote(_ note: Note) {
        guard let userId = authManager.user?.uid else { return }
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
        }
        
        // Delete from Core Data
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND userId == %@", note.id, userId)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let noteToDelete = results.first {
                viewContext.delete(noteToDelete)
                try viewContext.save()
            }
        } catch {
            print("Error deleting note from Core Data: \(error)")
        }
        
        // If online, delete from Firebase
        if connectivityManager.isConnected {
            deleteNoteFromFirebase(note)
        } else {
            // Add to deletedNoteIds for syncing later
            deletedNoteIds.insert("\(userId):\(note.id)")
            UserDefaults.standard.setDeletedNoteIds(deletedNoteIds)
        }
    }
    
    private func deleteNoteFromFirebase(_ note: Note) {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("notes").document(note.id).delete { error in
            if let error = error {
                print("Error deleting note from Firebase: \(error.localizedDescription)")
            } else {
                // Remove from deletedNoteIds if successfully deleted
                deletedNoteIds.remove("\(userId):\(note.id)")
                UserDefaults.standard.setDeletedNoteIds(deletedNoteIds)
            }
        }
    }
    
    private func syncPendingChanges() {
        guard connectivityManager.isConnected, let userId = authManager.user?.uid else { return }
        
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "needsSync == true AND userId == %@", userId)
        
        do {
            let notesToSync = try viewContext.fetch(fetchRequest)
            for cdNote in notesToSync {
                let note = cdNote.toNote()
                syncNoteToFirebase(note)
            }
        } catch {
            print("Error fetching notes to sync: \(error)")
        }
        
        // Sync deleted notes
        let deletedNotesToSync = deletedNoteIds.filter { $0.hasPrefix("\(userId):") }
        for deletedNoteId in deletedNotesToSync {
            let actualNoteId = String(deletedNoteId.dropFirst(userId.count + 1))
            let dummyNote = Note(id: actualNoteId, content: "", timestamp: Date(), userId: userId)
            deleteNoteFromFirebase(dummyNote)
        }
        
        // Check if unpinned notes need to be deleted from Firebase
        if UserDefaults.standard.bool(forKey: "unpinnedNotesNeedDeletion") {
            deleteUnpinnedNotesFromFirebase()
        }
    }
    
    private func deleteUnpinnedNotesFromFirebase() {
        guard let userId = authManager.user?.uid else { return }
        
        let db = Firestore.firestore()
        let notesRef = db.collection("users").document(userId).collection("notes")
        
        notesRef.whereField("isPinned", isEqualTo: false).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                for document in querySnapshot!.documents {
                    document.reference.delete()
                }
            }
            // Clear the flag for future deletion
            UserDefaults.standard.set(false, forKey: "unpinnedNotesNeedDeletion")
        }
    }
    
    private func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                notes[index].isPinned.toggle()
            }
            updateNote(notes[index])
        }
    }
    
    private var userProfileButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            if let imageURL = userProfileImageURL {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
            }
        }
    }
    
    private func loadUserProfileImageURL() {
        if let photoURL = Auth.auth().currentUser?.photoURL {
            userProfileImageURL = photoURL
        }
    }
    
    private func logout() {
        withAnimation {
            isLoggingOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Simulating network delay
            authManager.signOut()
            withAnimation {
                isLoggingOut = false
            }
        }
    }
    
    private func setNavigationBarFont() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)]
        appearance.titleTextAttributes = [.font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)]
    }
    
    // Add this method to the ContentView struct
    private func setupDeletedNoteIdsObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { _ in
                self.deletedNoteIds = UserDefaults.standard.deletedNoteIds()
            }
            .store(in: &cancellables)
    }
    
    // Add this function
    private func confirmDelete() {
        if let noteToDelete = noteToDelete {
            deleteNote(noteToDelete)
        }
        noteToDelete = nil
    }
    
    private var refreshButton: some View {
        Button(action: {
            refreshNotes()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 18))
                .foregroundColor(connectivityManager.isConnected ? 
                    (colorScheme == .dark ? .draculaGreen : .draculaGreen) : .gray)
                .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .disabled(!connectivityManager.isConnected || isRefreshing)
    }
    
    private func refreshNotes() {
        guard connectivityManager.isConnected else {
            // Show an alert or message that refresh is not available offline
            return
        }
        
        isRefreshing = true
        fetchNotesFromFirebase(page: 1) { success in
            isRefreshing = false
            if success {
                // Optionally show a success message
            } else {
                // Show an error message
            }
        }
    }
    
    private func fetchNotesFromFirebase(page: Int, completion: @escaping (Bool) -> Void) {
        guard let userId = authManager.user?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let notesRef = db.collection("users").document(userId).collection("notes")
        
        notesRef
            .order(by: "timestamp", descending: true)
            .limit(to: notesPerPage * page)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching documents: \(error)")
                    completion(false)
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents")
                    completion(false)
                    return
                }
                
                let fetchedNotes = documents.compactMap { document -> Note? in
                    let data = document.data()
                    guard let content = data["content"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                          let isPinned = data["isPinned"] as? Bool else {
                        return nil
                    }
                    return Note(id: document.documentID, content: content, timestamp: timestamp, isPinned: isPinned, userId: userId)
                }
                
                DispatchQueue.main.async {
                    if page == 1 {
                        self.notes = fetchedNotes
                    } else {
                        self.notes.append(contentsOf: fetchedNotes)
                    }
                    self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
                    self.syncNotesToCoreData(fetchedNotes)
                    completion(true)
                }
            }
    }
    
    private func checkForUnpinnedNotesDeletion() {
        if UserDefaults.standard.bool(forKey: "unpinnedNotesNeedDeletion") {
            // Remove unpinned notes from the local array
            notes = notes.filter { $0.isPinned }
        }
    }
    
    private var pasteButton: some View {
        Button(action: {
            if let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty {
                isCreatingNoteFromClipboard = true
            }
        }) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18))
                .foregroundColor(colorScheme == .dark ? .draculaPurple : .draculaPurple)
        }
    }
    
    private func syncNotesToCoreData(_ fetchedNotes: [Note]) {
        for note in fetchedNotes {
            let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", note.id)
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let existingNote = results.first {
                    // Update existing note
                    existingNote.content = note.content
                    existingNote.timestamp = note.timestamp
                    existingNote.isPinned = note.isPinned
                    existingNote.userId = note.userId
                    existingNote.needsSync = false
                } else {
                    // Create new note
                    let newNote = CDNote(context: viewContext)
                    newNote.id = note.id
                    newNote.content = note.content
                    newNote.timestamp = note.timestamp
                    newNote.isPinned = note.isPinned
                    newNote.userId = note.userId
                    newNote.needsSync = false
                }
            } catch {
                print("Error fetching note from Core Data: \(error)")
            }
        }
        
        // Save changes
        do {
            try viewContext.save()
        } catch {
            print("Error saving notes to Core Data: \(error)")
        }
    }
    
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 20/255, green: 21/255, blue: 28/255) // Even darker background for dark mode
        } else {
            return Color.white // Normal white for light mode
        }
    }
}

