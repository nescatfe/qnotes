import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.draculaBackground
                .ignoresSafeArea()
            
            VStack {
                Image("Qnote_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                
                Text("Qnote")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.draculaForeground)
                    .padding(.top, 20)
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}