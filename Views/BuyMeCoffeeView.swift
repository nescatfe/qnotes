import SwiftUI

struct BuyMeCoffeeView: View {
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cup.and.saucer.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(Color.draculaOrange)
            
            Text("Support Qnote Development")
                .font(.title)
                .fontWeight(.bold)
            
            Text("If you enjoy using Qnote, consider buying me a coffee to support ongoing development and improvements.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                // Replace with your actual Buy Me a Coffee link
                if let url = URL(string: "https://www.buymeacoffee.com/yourlink") {
                    openURL(url)
                }
            }) {
                Text("Buy Me a Coffee")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.draculaOrange)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Buy Me a Coffee")
    }
}