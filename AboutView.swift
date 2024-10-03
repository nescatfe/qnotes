import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var rotationAngle: Double = 0
    @State private var rotationSpeed: Double = 0.5
    @State private var lastTapTime: Date = Date()
    @State private var secretMessageOpacity: Double = 0
    @State private var tapCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("Qnote_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1), value: rotationAngle)
                    .onTapGesture {
                        handleLogoTap()
                    }
                
                Text("Qnote")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                
                Text(appDescription)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaForeground : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onTapGesture(count: 3) {
                        handleTripleTap()
                    }
                
                Text("© 2024 Qnote. All rights reserved.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(colorScheme == .dark ? .draculaComment : .gray)
                    .padding(.top)
                
                Text("You found a secret! 🎉")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.draculaPink)
                    .opacity(secretMessageOpacity)
                    .animation(.easeInOut(duration: 0.5), value: secretMessageOpacity)
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.draculaBackground : Color(.systemBackground))
        .navigationBarTitle("About", displayMode: .inline)
    }
    
    private func handleLogoTap() {
        let currentTime = Date()
        let timeSinceLastTap = currentTime.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.5 {
            // Increase rotation speed if tapped quickly
            rotationSpeed = min(rotationSpeed * 1.5, 10)
        } else {
            // Reset rotation speed if tapped slowly
            rotationSpeed = 0.5
        }
        
        // Update rotation angle
        rotationAngle += 360 * rotationSpeed
        
        // Update last tap time
        lastTapTime = currentTime
    }
    
    private func handleTripleTap() {
        tapCount += 1
        
        if tapCount == 3 {
            withAnimation {
                secretMessageOpacity = 1
            }
            
            // Hide the secret message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    secretMessageOpacity = 0
                }
                tapCount = 0
            }
        }
    }
    
    private var appDescription: String {
        """
        Qnote is a powerful and intuitive note-taking app designed for simplicity and efficiency. With seamless synchronization across devices and offline capabilities, Qnote ensures your thoughts are always at your fingertips.

        Key Features:
        • Clean, distraction-free interface
        • Real-time sync with Firebase
        • Offline mode with Core Data
        • Dark mode support
        • Pin important notes
        • Quick search functionality
        • Secure authentication

        Qnote helps you capture ideas, make lists, and keep track of important information with ease. Whether you're a student, professional, or anyone who loves to jot down thoughts, Qnote is the perfect companion for your note-taking needs.
        """
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}