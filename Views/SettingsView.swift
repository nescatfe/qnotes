import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreData

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
                deleteUnpinnedNotesButton
            }
            
            Section {
                logoutButton
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(colorScheme == .dark ? Color.draculaBackground : Color(.systemGroupedBackground))
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
    }
    
    private var userProfileSection: some View {
        HStack {
            if let imageURL = authManager.user?.photoURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                        .frame(width: 80, height: 80)
                }
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
                Text("1.0.0")
                    .foregroundColor(.gray)
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
                    document.reference.delete()
                }
            }
            // Clear the flag for future deletion
            UserDefaults.standard.set(false, forKey: "unpinnedNotesNeedDeletion")
        }
    }
    
    private var logoutButton: some View {
        Button(action: {
            showingLogoutConfirmation = true
        }) {
            HStack {
                Spacer()
                Text("Log Out")
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .padding()
        .background(connectivityManager.isConnected ? Color.red : Color.gray)
        .cornerRadius(10)
        .disabled(!connectivityManager.isConnected)
    }
}