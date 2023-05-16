import SwiftUI

struct ContentView: View {
    @StateObject private var previewState = PreviewState()
    @State private var showSettings = false
    @State private var userInput = ""
    @State private var webViewUrl = ""
    @State private var showWebView = false
    @State private var toggleButton = false

    var body: some View {
        ZStack {
            VStack {
//                Text("Model: " + previewState.models.keys.sorted().joined(separator:", "))
//                    .font(.system(size: 14, weight: .bold, design: .rounded))

                HostedViewController(previewState: previewState)
                    .ignoresSafeArea()
                    .padding(.top, 10)

                Toggle("Preview", isOn: $previewState.isPreviewEnabled)
                    .padding()

                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 24))
                        .padding()
                }
                if !showWebView {
                    TextField("Enter URL", text: $userInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        webViewUrl = userInput
                    }) {
                        Text("Load URL")
                    }
                    .padding(.bottom)
                }
                
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(previewState: previewState)
            }
            
            if !webViewUrl.isEmpty && showWebView {
                WebView(urlString: webViewUrl, previewState: previewState)
                    .id(webViewUrl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Set the height to .infinity for full screen
                    .ignoresSafeArea()
            }
            
            VStack {
                Button(action: {
                    showWebView.toggle()
                }) {
                    Text(showWebView ? "Hide WebView" : "Show WebView")
                }
                Spacer() // Add Spacer after the button to push it to the top of the vstack
                .padding(.bottom)
            }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
