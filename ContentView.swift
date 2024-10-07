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
import UIKit

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
    @State private var isSearching = false
    @State private var searchResults: [Note] = []
    @State private var searchCancellable: AnyCancellable?
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
    @State private var isUploading = false
    @State private var showingPasteAlert = false
    @State private var clipboardContent: String = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showCopiedNotification = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                NavigationStack {
                    ZStack {
                        VStack(spacing: 0) {
                            searchBar
                                .padding(.top, 8)
                            notesList
                        }
                        
                        if !notes.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    floatingActionButtons
                                }
                            }
                        }
                        
                        if showCopiedNotification {
                            copiedNotificationView
                        }
                    }
                    .navigationTitle("Qnote")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 16) {
                                refreshButton
                                userProfileButton
                            }
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
                    .alert(isPresented: $showingPasteAlert) {
                        Alert(
                            title: Text("Create Note from Clipboard"),
                            message: Text("Do you want to create a new note from the clipboard content?"),
                            primaryButton: .default(Text("Create")) {
                                createNoteFromClipboard()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                    .alert("Error", isPresented: $showingErrorAlert, actions: {
                        Button("OK", role: .cancel) {}
                    }, message: {
                        Text(errorMessage)
                    })
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
            ZStack {
                VStack(spacing: 0) {
                    searchBar
                        .padding(.top, 8)
                    notesList
                }
                
                if !notes.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            floatingActionButtons
                        }
                    }
                }
                
                if showCopiedNotification {
                    copiedNotificationView
                }
            }
            .navigationTitle("Qnote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        refreshButton
                        userProfileButton
                    }
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
            .alert(isPresented: $showingPasteAlert) {
                Alert(
                    title: Text("Create Note from Clipboard"),
                    message: Text("Do you want to create a new note from the clipboard content?"),
                    primaryButton: .default(Text("Create")) {
                        createNoteFromClipboard()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Error", isPresented: $showingErrorAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage)
            })
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
    }
    
    private func onAuthenticatedAppear() {
        setNavigationBarFont()
        cleanupDeletedNotes() // Add this line
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
        SearchBarView(
            searchText: $searchText,
            isSearching: $isSearching,
            performSearch: performSearch,
            clearSearch: clearSearch
        )
    }
    
    private func performSearch() {
        isSearching = true
        searchResults = notes.filter { note in
            note.content.lowercased().contains(searchText.lowercased())
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func clearSearch() {
        searchText = ""
        isSearching = false
        searchResults = []
    }
    
    private var notesList: some View {
        Group {
            if notes.isEmpty {
                emptyNotesView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(isSearching ? searchResults : filteredNotes) { note in
                            NavigationLink(value: note) {
                                NoteRowView(note: note, isRefreshing: isRefreshing)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                noteContextMenu(for: note)
                            }
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
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .scale.combined(with: .opacity)))
                        }
                        
                        if hasMoreNotes && !isSearching {
                            ProgressView()
                                .onAppear {
                                    loadMoreNotes()
                                }
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredNotes)
                }
            }
        }
    }
    
    private func noteContextMenu(for note: Note) -> some View {
        Group {
            Button(action: {
                togglePin(note)
            }) {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Button(action: {
                togglePublic(note)
            }) {
                Label(note.isPublic ? "Make Private" : "Make Public", systemImage: note.isPublic ? "lock" : "globe")
            }
            
            if note.isPublic {
                Button(action: {
                    copyPublicLink(for: note)
                }) {
                    Label("Copy Public Link", systemImage: "link")
                }
            }
            
            Button(action: {
                UIPasteboard.general.string = note.content
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            if !note.isPinned {
                Button(role: .destructive, action: {
                    noteToDelete = note
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private var emptyNotesView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 70))
                .foregroundColor(.draculaComment)
            
            VStack(spacing: 16) {
                Text("No Notes Yet")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                
                Text("Start capturing your thoughts and ideas")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(.draculaComment)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Button(action: { isAddingNewNote = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Note")
                    }
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.draculaGreen)
                    .cornerRadius(12)
                }
                
                Button(action: checkClipboardAndShowAlert) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.draculaPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.draculaPurple.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Text("Tap '+' to add a new note anytime")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.draculaComment)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }
    
    private var filteredNotes: [Note] {
        notes.sorted { 
            if $0.isPinned == $1.isPinned {
                return $0.timestamp > $1.timestamp
            }
            return $0.isPinned && !$1.isPinned
        }
    }
    
    private func fetchNotes() {
        isLoading = true
        currentPage = 1
        hasMoreNotes = true
        
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", authManager.user?.uid ?? "")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.timestamp, ascending: false)]
        fetchRequest.fetchLimit = notesPerPage
        
        do {
            let fetchedCDNotes = try viewContext.fetch(fetchRequest)
            let fetchedNotes = fetchedCDNotes.map { $0.toNote() }
            
            DispatchQueue.main.async {
                self.notes = fetchedNotes
                self.isLoading = false
                self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
            }
        } catch {
            print("Error fetching notes: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to fetch notes: \(error.localizedDescription)"
                self.showingErrorAlert = true
            }
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
                    print("Error fetching notes: \(error)")
                    self.errorMessage = "Failed to fetch notes: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                    self.isLoading = false
                } else {
                    let fetchedNotes = querySnapshot?.documents.compactMap { document -> Note? in
                        let data = document.data()
                        let id = document.documentID
                        let content = data["content"] as? String ?? ""
                        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        let isPinned = data["isPinned"] as? Bool ?? false
                        let isPublic = data["isPublic"] as? Bool ?? false
                        let publicId = data["publicId"] as? String
                        
                        return Note(id: id,
                                    content: content,
                                    timestamp: timestamp,
                                    isPinned: isPinned,
                                    userId: userId,
                                    syncState: .synced,
                                    needsSync: false,
                                    isPublic: isPublic,
                                    publicId: publicId)
                    } ?? []
                    
                    DispatchQueue.main.async {
                        if page == 1 {
                            self.notes = fetchedNotes
                        } else {
                            self.notes.append(contentsOf: fetchedNotes)
                        }
                        self.isLoading = false
                        self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
                    }
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
        notes.insert(note, at: 0)
        saveNoteToCoreData(note)
        if note.content.count <= 800000 {
            syncNote(note)
        } else {
            print("New note exceeds 800,000 characters. Keeping it local only.")
        }
    }
    
    private func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
        
        saveNoteToCoreData(note)
        
        if connectivityManager.isConnected {
            uploadNoteToFirebase(note) { success in
                if success {
                    DispatchQueue.main.async {
                        if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                            self.notes[index].syncState = .synced
                            self.notes[index].needsSync = false
                        }
                    }
                }
            }
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
        
        // If the note is public, delete it from the public notes collection
        if note.isPublic, let publicId = note.publicId {
            deletePublicNote(publicId: publicId)
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
    
    private func deletePublicNote(publicId: String) {
        let db = Firestore.firestore()
        db.collection("public_notes").document(publicId).delete { error in
            if let error = error {
                print("Error deleting public note: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncPendingChanges() {
        guard connectivityManager.isConnected, let userId = authManager.user?.uid else { return }
        
        let notesToSync = notes.filter { $0.needsSync || $0.syncState == .notSynced }
        
        for note in notesToSync {
            syncNote(note)
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].isPinned.toggle()
                
                // Move the note to the appropriate position
                let updatedNote = notes.remove(at: index)
                if updatedNote.isPinned {
                    notes.insert(updatedNote, at: 0)
                } else {
                    let insertIndex = notes.firstIndex(where: { !$0.isPinned }) ?? notes.count
                    notes.insert(updatedNote, at: insertIndex)
                }
                
                updateNote(notes[notes.firstIndex(where: { $0.id == note.id })!])
            }
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
                // Save fetched notes to Core Data
                self.syncNotesToCoreData(self.notes)
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
                    let isPublic = data["isPublic"] as? Bool ?? false
                    let publicId = data["publicId"] as? String
                    
                    return Note(id: document.documentID,
                                content: content,
                                timestamp: timestamp,
                                isPinned: isPinned,
                                userId: userId,
                                syncState: .synced,
                                needsSync: false,
                                isPublic: isPublic,
                                publicId: publicId)
                }
                
                DispatchQueue.main.async {
                    if page == 1 {
                        self.notes = fetchedNotes
                    } else {
                        self.notes.append(contentsOf: fetchedNotes)
                    }
                    self.isLoading = false
                    self.hasMoreNotes = fetchedNotes.count == self.notesPerPage
                    
                    // Save fetched notes to Core Data
                    self.syncNotesToCoreData(self.notes)
                    
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
    
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 20/255, green: 21/255, blue: 28/255) // Even darker background for dark mode
        } else {
            return Color.white // Normal white for light mode
        }
    }
    
    private func syncNotesToCoreData(_ fetchedNotes: [Note]) {
        // Create a background context
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        backgroundContext.performAndWait {
            // Fetch all existing notes at once
            let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", fetchedNotes.map { $0.id })
            
            do {
                let existingNotes = try backgroundContext.fetch(fetchRequest)
                let existingNoteDict = Dictionary(uniqueKeysWithValues: existingNotes.map { ($0.id!, $0) })
                
                for note in fetchedNotes {
                    if let existingNote = existingNoteDict[note.id] {
                        // Update existing note
                        existingNote.content = note.content
                        existingNote.timestamp = note.timestamp
                        existingNote.isPinned = note.isPinned
                        existingNote.userId = note.userId
                        existingNote.needsSync = false
                        existingNote.syncStateEnum = note.syncState
                        existingNote.isPublic = note.isPublic
                        existingNote.publicId = note.publicId
                    } else {
                        // Create new note
                        let newNote = CDNote(context: backgroundContext)
                        newNote.id = note.id
                        newNote.content = note.content
                        newNote.timestamp = note.timestamp
                        newNote.isPinned = note.isPinned
                        newNote.userId = note.userId
                        newNote.needsSync = false
                        newNote.syncStateEnum = note.syncState
                        newNote.isPublic = note.isPublic
                        newNote.publicId = note.publicId
                    }
                }
                
                // Save changes
                try backgroundContext.save()
            } catch {
                print("Error syncing notes to Core Data: \(error)")
            }
        }
    }
    
    private func syncNote(_ note: Note) {
        guard note.content.count <= 800000 else {
            print("Note exceeds 800,000 characters. Keeping it local only.")
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].syncState = .notSynced
                notes[index].needsSync = false // Mark as not needing sync since it's too large
                updateNoteInCoreData(notes[index])
            }
            return
        }
        
        if !connectivityManager.isConnected {
            markNoteForSync(note)
            return
        }
        
        uploadNoteToFirebase(note) { success in
            if success {
                DispatchQueue.main.async {
                    if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                        self.notes[index].syncState = .synced
                        self.updateNoteInCoreData(self.notes[index])
                    }
                }
            } else {
                // If upload fails, mark the note for future sync
                self.markNoteForSync(note)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to sync note with Firebase. It will be synced when connection is available."
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func markNoteForSync(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].syncState = .notSynced
            notes[index].needsSync = note.content.count <= 800000 // Only mark for sync if within character limit
            updateNoteInCoreData(notes[index])
        }
    }
    
    private func updateNoteInCoreData(_ note: Note) {
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", note.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existingNote = results.first {
                existingNote.content = note.content
                existingNote.timestamp = note.timestamp
                existingNote.isPinned = note.isPinned
                existingNote.userId = note.userId
                existingNote.needsSync = false
                existingNote.syncStateEnum = .synced
                
                try viewContext.save()
            }
        } catch {
            print("Error updating note in Core Data: \(error)")
        }
    }
    
    private func saveNoteToCoreData(_ note: Note) {
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", note.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let cdNote: CDNote
            if let existingNote = results.first {
                cdNote = existingNote
            } else {
                cdNote = CDNote(context: viewContext)
                cdNote.id = note.id
            }
            
            cdNote.content = note.content
            cdNote.timestamp = note.timestamp
            cdNote.isPinned = note.isPinned
            cdNote.userId = note.userId
            cdNote.needsSync = true
            cdNote.syncStateEnum = .notSynced
            cdNote.isPublic = note.isPublic
            cdNote.publicId = note.publicId
            
            try viewContext.save()
        } catch {
            print("Error saving note to Core Data: \(error)")
            errorMessage = "Failed to save note: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func uploadNoteToFirebase(_ note: Note, completion: @escaping (Bool) -> Void) {
        guard let userId = authManager.user?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let noteRef = db.collection("users").document(userId).collection("notes").document(note.id)
        
        var data: [String: Any] = [
            "content": note.content,
            "timestamp": note.timestamp,
            "isPinned": note.isPinned,
            "isPublic": note.isPublic
        ]
        
        if let publicId = note.publicId {
            data["publicId"] = publicId
        }
        
        noteRef.setData(data, merge: true) { error in
            if let error = error {
                print("Error uploading note: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    private var floatingActionButtons: some View {
        HStack(spacing: 0) {
            Button(action: {
                checkClipboardAndShowAlert()
            }) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .foregroundColor(.white)
                .frame(height: 40)
                .frame(width: 100)
                .background(Color.draculaPurple)
            }
            
            Button(action: { isAddingNewNote = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create")
                }
                .foregroundColor(.white)
                .frame(height: 40)
                .frame(width: 100)
                .background(Color.draculaGreen)
            }
        }
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func checkClipboardAndShowAlert() {
        if let content = UIPasteboard.general.string, !content.isEmpty {
            showingPasteAlert = true
        } else {
            errorMessage = "The clipboard is empty or its content cannot be accessed."
            showingErrorAlert = true
        }
    }
    
    private func createNoteFromClipboard() {
        guard let content = UIPasteboard.general.string, !content.isEmpty else {
            errorMessage = "Failed to create note: The clipboard is empty or its content cannot be accessed."
            showingErrorAlert = true
            return
        }
        
        guard let userId = authManager.user?.uid else {
            errorMessage = "Failed to create note: User ID is not available."
            showingErrorAlert = true
            return
        }
        
        let newNote = Note(content: content, timestamp: Date(), userId: userId)
        addNote(newNote)
    }
    
    private func cleanupDeletedNotes() {
        guard let userId = authManager.user?.uid else { return }
        
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let allNotes = try viewContext.fetch(fetchRequest)
            let deletedNoteIds = UserDefaults.standard.deletedNoteIds()
            
            for note in allNotes {
                if deletedNoteIds.contains(note.id ?? "") {
                    viewContext.delete(note)
                }
            }
            
            try viewContext.save()
            
            // Clear the deletedNoteIds after cleanup
            UserDefaults.standard.setDeletedNoteIds(Set<String>())
        } catch {
            print("Error cleaning up deleted notes: \(error)")
        }
    }
    
    private func togglePublic(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isPublic.toggle()
            if notes[index].isPublic {
                makeNotePublic(notes[index])
            } else {
                makeNotePrivate(notes[index])
            }
        }
    }
    
    private func makeNotePublic(_ note: Note) {
        let publicId = generateShortId()
        let publicNoteRef = Firestore.firestore().collection("public_notes").document(publicId)
        
        publicNoteRef.setData([
            "content": note.content,
            "timestamp": Timestamp(date: note.timestamp),
            "userId": note.userId,
            "publicId": publicId
        ]) { error in
            if let error = error {
                print("Error making note public: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                        self.notes[index].isPublic = true
                        self.notes[index].publicId = publicId
                        self.updateNote(self.notes[index])
                    }
                }
            }
        }
    }
    
    private func makeNotePrivate(_ note: Note) {
        guard let publicId = note.publicId else { return }
        
        let publicNoteRef = Firestore.firestore().collection("public_notes").document(publicId)
        
        publicNoteRef.delete { error in
            if let error = error {
                print("Error making note private: \(error)")
            } else {
                DispatchQueue.main.async {
                    if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                        self.notes[index].isPublic = false
                        self.notes[index].publicId = nil
                        self.updateNote(self.notes[index])
                    }
                }
            }
        }
    }
    
    private func copyPublicLink(for note: Note) {
        guard let publicId = note.publicId else { return }
        let link = "https://qnote.malvi.lol/p/\(publicId)"
        UIPasteboard.general.string = link
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedNotification = false
            }
        }
    }
    
    private func generateShortId() -> String {
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
    
    private var copiedNotificationView: some View {
        VStack {
            Spacer()
            Text("Link copied to clipboard")
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
}