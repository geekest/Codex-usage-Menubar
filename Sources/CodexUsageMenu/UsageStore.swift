import AppKit
import Combine
import Foundation
import WebKit

@MainActor
final class UsageStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var state: UsageState = .idle

    private let webSession = ChatGPTWebSession()
    private var timer: Timer?

    override init() {
        super.init()
        webSession.onPageText = { [weak self] text in self?.consume(pageText: text) }
        webSession.onLoginRequired = { [weak self] in self?.state = .needsLogin }
        webSession.onLoadFailure = { [weak self] message in self?.state = .failed(message) }
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        state = .refreshing
        webSession.loadUsagePage()
    }

    func showLogin() {
        webSession.showLoginWindow()
    }

    private func consume(pageText: String) {
        guard let parsed = UsageTextParser.parse(pageText) else {
            state = .failed("未能识别用量字段")
            return
        }
        snapshot = parsed
        state = .ready
    }
}

@MainActor
final class ChatGPTWebSession: NSObject, WKNavigationDelegate {
    var onPageText: ((String) -> Void)?
    var onLoginRequired: (() -> Void)?
    var onLoadFailure: ((String) -> Void)?

    private let usageURL = URL(string: "https://chatgpt.com/codex/settings/usage")!
    private let webView: WKWebView
    private let loginWindow: NSWindow

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        loginWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        webView.navigationDelegate = self
        loginWindow.title = "登录 ChatGPT"
        loginWindow.contentView = webView
        loginWindow.center()
        loginWindow.isReleasedWhenClosed = false
    }

    func showLoginWindow() {
        loginWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if webView.url == nil { loadUsagePage() }
    }

    func loadUsagePage() {
        webView.load(URLRequest(url: usageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let acceptedHosts = ["chatgpt.com", "auth.openai.com", "openai.com"]
        guard let host = url.host, acceptedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            onLoadFailure?("登录页面跳转到了未知域名")
            return
        }

        guard host.hasSuffix("chatgpt.com"), url.path.contains("/codex/settings/usage") else {
            onLoginRequired?()
            return
        }

        let script = """
        (() => {
          const aria = Array.from(document.querySelectorAll('[aria-label]'))
            .map(node => node.getAttribute('aria-label'))
            .filter(Boolean)
            .join('\\n');
          return [document.body ? document.body.innerText : '', aria].join('\\n');
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error {
                self?.onLoadFailure?("页面读取失败：\(error.localizedDescription)")
            } else if let text = result as? String {
                self?.onPageText?(text)
            } else {
                self?.onLoadFailure?("页面未返回可解析内容")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadFailure?("网络加载失败：\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadFailure?("网络连接失败：\(error.localizedDescription)")
    }
}
