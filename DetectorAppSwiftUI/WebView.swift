import SwiftUI
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebView

    init(_ parent: WebView) {
        self.parent = parent
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("window.post_message?.('Hello, World!')") { (result, error) in
            if let error = error {
                print("Error executing JavaScript: \(error.localizedDescription)")
            } else {
                print("JavaScript executed successfully")
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        } else {
            print("Could not create URL")
        }
    }
}
