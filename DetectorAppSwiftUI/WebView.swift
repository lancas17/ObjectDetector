import SwiftUI
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebView
    var heartbeatTimer: Timer?
    weak var webView: WKWebView?

    init(_ parent: WebView, webView: WKWebView) {
            self.parent = parent
            self.webView = webView
        }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setupHeartbeatTimer()
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.evaluateJavaScript("window.post_message?.('Hello, World!')") { (result, error) in
            if let error = error {
                print("Error executing JavaScript: \(error.localizedDescription)")
            } else {
                print("JavaScript executed successfully")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("called webView with didReceive")
        if let url = webView.url, url.host?.isIPAddress() == true, challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
            print("if statement")
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    
    func sendDetectedObjectsToWebView(_ webView: WKWebView, detectedObjects: [[String: Any]]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: detectedObjects, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let javascript = "window.post_message?.('{\"type\": \"detectedObjects\", \"objects\": \(jsonString)}')"
            webView.evaluateJavaScript(javascript) { (result, error) in
                if let error = error {
                    print("Error executing JavaScript: \(error.localizedDescription)")
                } else {
                    print("JavaScript executed successfully")
                }
            }
        } catch {
            print("Error creating JSON data: \(error.localizedDescription)")
        }
    }
    
    func setupHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let webView = self.webView else { return }
            self.sendHeartbeatToServer(webView)
        }
    }

    func sendHeartbeatToServer(_ webView: WKWebView) {
        let javascript = "window.post_message?.('{\"type\": \"heartbeat\"}')"
        webView.evaluateJavaScript(javascript) { (result, error) in
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
}

struct WebView: UIViewRepresentable {
    let urlString: String
    @ObservedObject var previewState: PreviewState

    func makeCoordinator() -> WebViewCoordinator {
        let webView = WKWebView()
        return WebViewCoordinator(self, webView: webView)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = context.coordinator.webView
        webView?.navigationDelegate = context.coordinator
        webView?.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
//        webView?.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        return webView ?? WKWebView()
    }


    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        } else {
            print("Could not create URL")
        }
        
        context.coordinator.sendDetectedObjectsToWebView(uiView, detectedObjects: previewState.detectedObjects)
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
