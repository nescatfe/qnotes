import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreData
import SDWebImageSwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var showingLogoutConfirmation: Bool
    @ObservedObject var connectivityManager: ConnectivityManager
    @State private var showingDeleteConfirmation = false
    @State private var showingSecondDeleteConfirmation = false
    @State private var showingFinalDeleteConfirmation = false
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @Binding var notes: [Note]
    @State private var userProfileImageURL: URL?
    @State private var showingAllNotes = false
    @State private var showingDeleteAllNotesConfirmation = false
    
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 20/255, green: 21/255, blue: 28/255) // Even darker background for dark mode
        } else {
            return Color.white // Normal white for light mode
        }
    }

    var body: some View {
        List {
            Section {
                userProfileSection
            }
            .listRowBackground(Color.clear)
            
            Section {
                accountInfoSection
            }
            
            Section {
                appInfoSection
            }
            
            Section {
                internetStatusSection
            }
            
            Section {
                allNotesButton
                deleteAllNotesButton
            }
            
            Section {
                deleteUnpinnedNotesButton
                logoutButton
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(backgroundColor)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete All Unpinned Notes", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed", role: .destructive) {
                showingSecondDeleteConfirmation = true
            }
        } message: {
            Text("Are you sure you want to delete all unpinned notes?")
        }
        .alert("Confirm Deletion", isPresented: $showingSecondDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed", role: .destructive) {
                showingFinalDeleteConfirmation = true
            }
        } message: {
            Text("This action cannot be undone. Are you absolutely sure?")
        }
        .alert("Final Confirmation", isPresented: $showingFinalDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteUnpinnedNotes()
            }
        } message: {
            Text("aRe yOu SoOoerr?")
        }
        .alert("Delete All Notes", isPresented: $showingDeleteAllNotesConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllNotes()
            }
        } message: {
            Text("This will delete all notes from your device. This action cannot be undone. Are you sure?")
        }
        .sheet(isPresented: $showingAllNotes) {
            AllNotesView()
        }
    }
    
    private var userProfileSection: some View {
        HStack {
            if let imageURL = userProfileImageURL {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.user?.displayName ?? "User")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                Text(authManager.user?.email ?? "")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .onAppear {
            loadUserProfileImageURL()
        }
    }
    
    private func loadUserProfileImageURL() {
        if let photoURL = Auth.auth().currentUser?.photoURL {
            userProfileImageURL = photoURL
        }
    }
    
    private var accountInfoSection: some View {
        Group {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.draculaPurple)
                    .frame(width: 30)
                Text("Email")
                Spacer()
                Text(authManager.user?.email ?? "Not available")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.draculaGreen)
                    .frame(width: 30)
                Text("User ID")
                Spacer()
                Text(authManager.user?.uid.prefix(8) ?? "Not available")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private var appInfoSection: some View {
        Group {
            NavigationLink {
                AboutView()
            } label: {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.draculaYellow)
                        .frame(width: 30)
                    Text("About Qnote")
                    Spacer()
                }
            }
            
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.draculaPink)
                    .frame(width: 30)
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    .foregroundColor(.gray)
            }
            
            NavigationLink {
                BuyMeCoffeeView()
            } label: {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.draculaOrange)
                        .frame(width: 30)
                    Text("Buy Me a Coffee")
                    Spacer()
                }
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private var internetStatusSection: some View {
        HStack {
            Image(systemName: connectivityManager.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(connectivityManager.isConnected ? .draculaGreen : .draculaPink)
                .frame(width: 30)
            Text("Internet Status")
            Spacer()
            Text(connectivityManager.isConnected ? "Connected" : "Disconnected")
                .foregroundColor(connectivityManager.isConnected ? .draculaGreen : .draculaPink)
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private var deleteUnpinnedNotesButton: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 30)
                Text("Delete Unpinned Notes")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private func deleteUnpinnedNotes() {
        guard let userId = authManager.user?.uid else { return }
        
        // Delete from Core Data
        let fetchRequest: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isPinned == false AND userId == %@", userId)
        
        do {
            let notesToDelete = try viewContext.fetch(fetchRequest)
            for note in notesToDelete {
                viewContext.delete(note)
                
                // If the note is public, delete it from the public notes collection
                if note.isPublic, let publicId = note.publicId {
                    deletePublicNote(publicId: publicId)
                }
            }
            try viewContext.save()
            
            // Update the notes array in the parent view
            notes = notes.filter { $0.isPinned }
            
            // If connected, delete from Firebase
            if connectivityManager.isConnected {
                deleteUnpinnedNotesFromFirebase(userId: userId)
            } else {
                // Mark for future deletion when online
                UserDefaults.standard.set(true, forKey: "unpinnedNotesNeedDeletion")
            }
            
            // Dismiss the settings view and return to the main page
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error deleting unpinned notes from Core Data: \(error)")
        }
    }
    
    private func deleteUnpinnedNotesFromFirebase(userId: String) {
        let db = Firestore.firestore()
        let notesRef = db.collection("users").document(userId).collection("notes")
        
        notesRef.whereField("isPinned", isEqualTo: false).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                for document in querySnapshot!.documents {
                    let data = document.data()
                    if let isPublic = data["isPublic"] as? Bool, isPublic,
                       let publicId = data["publicId"] as? String {
                        self.deletePublicNote(publicId: publicId)
                    }
                    document.reference.delete()
                }
            }
            // Clear the flag for future deletion
            UserDefaults.standard.set(false, forKey: "unpinnedNotesNeedDeletion")
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
    
    private var logoutButton: some View {
        Button(action: {
            showingLogoutConfirmation = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                    .frame(width: 30)
                Text("Log Out")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
        .disabled(!connectivityManager.isConnected)
    }
    
    private var allNotesButton: some View {
        Button(action: {
            showingAllNotes = true
        }) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.draculaPurple)
                    .frame(width: 30)
                Text("View All Notes")
                Spacer()
                Text("\(notes.count)")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
    
    private var deleteAllNotesButton: some View {
        Button(action: {
            showingDeleteAllNotesConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .frame(width: 30)
                Text("Clear Cache")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .monospaced))
    }

    private func deleteAllNotes() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CDNote.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try viewContext.execute(batchDeleteRequest)
            try viewContext.save()

            // Update the notes array in the parent view
            notes.removeAll()

            // Dismiss the settings view and return to the main page
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error deleting all notes from Core Data: \(error)")
        }
    }
}

struct AllNotesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDNote.timestamp, ascending: false)],
        animation: .default)
    private var cdNotes: FetchedResults<CDNote>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(cdNotes) { cdNote in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cdNote.content ?? "")
                            .lineLimit(2)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                        Text(formatDate(cdNote.timestamp ?? Date()))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("ID: \(cdNote.id ?? "Unknown")")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.draculaComment)
                        Text("User ID: \(cdNote.userId ?? "Unknown")")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.draculaComment)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("All Notes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        DateFormatter.noteListFormatter.string(from: date)
    }
}