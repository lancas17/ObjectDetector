import SwiftUI
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebView
    var heartbeatTimer: Timer?
    var webView: WKWebView
    private var detectedObjects: [[String: Any]] = []

    init(_ parent: WebView, webView: WKWebView) {
        self.parent = parent
        self.webView = webView
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setupHeartbeatTimer()
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        executeJavascript(webView, script: "window.post_message?.('Hello, World!')")
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let url = webView.url, url.host?.isIPAddress() == true, challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func sendDetectedObjectsToWebView(_ webView: WKWebView, detectedObjects: [[String: Any]]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: detectedObjects, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let javascript = "window.post_message?.('{\"type\": \"detectedObjects\", \"objects\": \(jsonString)}')"
            executeJavascript(webView, script: javascript)
        } catch {
            print("Error creating JSON data: \(error.localizedDescription)")
        }
    }

    func setupHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sendHeartbeatToServer(self.webView)
        }
    }

    func sendHeartbeatToServer(_ webView: WKWebView) {
        let javascript = "window.post_message?.('{\"type\": \"heartbeat\"}')"
        executeJavascript(webView, script: javascript)
    }

    func executeJavascript(_ webView: WKWebView, script: String) {
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("Error executing JavaScript: \(error.localizedDescription)")
            } else {
                print("JavaScript executed successfully")
            }
        }
    }

    deinit {
        heartbeatTimer?.invalidate()
    }

    func updateDetectedObjects(detectedObjects: [[String: Any]]) {
        do {
            let newJSONData = try JSONSerialization.data(withJSONObject: detectedObjects, options: [])
            let newJSONString = String(data: newJSONData, encoding: .utf8) ?? ""

            let oldJSONData = try JSONSerialization.data(withJSONObject: self.detectedObjects, options: [])
            let oldJSONString = String(data: oldJSONData, encoding: .utf8) ?? ""

            if oldJSONString != newJSONString {
                self.detectedObjects = detectedObjects
                sendDetectedObjectsToWebView(webView, detectedObjects: detectedObjects)
            }
        } catch {
            print("Error creating JSON data: \(error.localizedDescription)")
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    @ObservedObject var previewState: PreviewState

    func makeCoordinator() -> WebViewCoordinator {
        print("makeCoordinator called")
        let webView = WKWebView()
        return WebViewCoordinator(self, webView: webView)
    }

    func makeUIView(context: Context) -> WKWebView {
        print("makeUIView called")
        let webView = context.coordinator.webView
        webView.navigationDelegate = context.coordinator
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("Could not create URL")
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("updateUIView called")
        // Handle the update of detected objects separately
        DispatchQueue.main.async {
            context.coordinator.updateDetectedObjects(detectedObjects: previewState.detectedObjects)
        }
    }
}


extension String {
    func isIPAddress() -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        return self.withCString { cstring in
            return inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1 || inet_pton(AF_INET, cstring, &sin.sin_addr) == 1
        }
    }
}
