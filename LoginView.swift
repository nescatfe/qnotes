import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoggingIn = false
    @State private var animateBackground = false
    @State private var logoRotation = 0.0
    @State private var logoOpacity = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                Image("Qnote_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.8)
                
                // Overlay gradient
                LinearGradient(gradient: Gradient(colors: [Color.draculaBackground.opacity(0.7), Color.draculaPurple.opacity(0.3)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .hueRotation(.degrees(animateBackground ? 30 : 0))
                    .animation(Animation.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateBackground)
                    .onAppear { animateBackground = true }
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Qnote logo
                    Image("Qnote_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(logoRotation))
                        .opacity(logoOpacity)
                    
                    // Welcome text
                    VStack(spacing: 10) {
                        Text("Welcome to Qnote")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Your secure and simple note-taking app")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    // Custom Google Sign-In Button
                    Button(action: {
                        isLoggingIn = true
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            logoRotation = 360
                        }
                        authManager.signInWithGoogle { success in
                            if success {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    logoOpacity = 0
                                }
                            } else {
                                isLoggingIn = false
                                withAnimation(.linear) {
                                    logoRotation = 0
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .disabled(isLoggingIn)
                    .opacity(isLoggingIn ? 0.7 : 1)
                    .scaleEffect(isLoggingIn ? 0.95 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isLoggingIn)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
        .overlay(
            Group {
                if isLoggingIn {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthenticationManager())
    }
}