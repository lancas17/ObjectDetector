import SwiftUI

struct ContentView: View {
    @StateObject private var previewState = PreviewState()
    @State private var showSettings = false
    @State private var userInput = ""
    @State private var webViewUrl = "http://192.168.43.118:3000"

    var body: some View {
        VStack {
            Text("Model: " + previewState.models.keys.sorted().joined(separator:", "))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.top, 10)

            HostedViewController(previewState: previewState)
                .ignoresSafeArea()

            Toggle("Preview", isOn: $previewState.isPreviewEnabled)
                .padding()

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 24))
                    .padding()
            }
            Text("My WebView")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.top, 10)

            TextField("Enter text", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                webViewUrl = "http://192.168.43.118:3000?input=\(userInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }) {
                Text("Send")
            }
            .padding(.bottom)

            WebView(urlString: webViewUrl)
                .id(webViewUrl) // Add this line
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(previewState: previewState)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
