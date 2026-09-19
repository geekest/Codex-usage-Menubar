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
final class ChatGPTWebSession: NSObject, WKNavigationDelegate, NSWindowDelegate {
    var onPageText: ((String) -> Void)?
    var onLoginRequired: (() -> Void)?
    var onLoadFailure: ((String) -> Void)?

    private let usageURL = URL(string: "https://chatgpt.com/codex/settings/usage")!
    private let webView: WKWebView
    private let loginWindow: NSWindow
    private let readRetryInterval: TimeInterval = 0.5
    private let maximumReadAttempts = 10
    private var requestID = UUID()
    private weak var activeNavigation: WKNavigation?

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
        loginWindow.delegate = self
        loginWindow.center()
        loginWindow.isReleasedWhenClosed = false
    }

    func showLoginWindow() {
        loginWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if webView.url == nil { loadUsagePage() }
    }

    func loadUsagePage() {
        requestID = UUID()
        activeNavigation = webView.load(
            URLRequest(url: usageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === activeNavigation else { return }
        guard let url = webView.url else { return }
        let acceptedHosts = ["chatgpt.com", "auth.openai.com", "openai.com"]
        guard let host = url.host, acceptedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            invalidateCurrentRequest()
            onLoadFailure?("登录页面跳转到了未知域名")
            return
        }

        guard host.hasSuffix("chatgpt.com"), url.path.contains("/codex/settings/usage") else {
            invalidateCurrentRequest()
            onLoginRequired?()
            return
        }

        readPageText(requestID: requestID, attempt: 1)
    }

    private func readPageText(requestID: UUID, attempt: Int) {
        let script = """
        (() => {
          const bodyText = document.body ? document.body.innerText : '';
          const aria = Array.from(document.querySelectorAll('[aria-label]'))
            .map(node => node.getAttribute('aria-label'))
            .filter(Boolean)
            .join('\\n');
          const hasUsageLabel = /(?:5\\s*hour|5h|five-hour|weekly|week|7\\s*day|seven-day|5\\s*小时|每周)/i.test(bodyText);
          return { ready: hasUsageLabel, text: [bodyText, aria].join('\\n') };
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self, requestID == self.requestID else { return }

            if error == nil,
               let response = result as? [String: Any],
               response["ready"] as? Bool == true,
               let text = response["text"] as? String {
                self.invalidateCurrentRequest()
                self.onPageText?(text)
                return
            }

            guard attempt < self.maximumReadAttempts else {
                self.invalidateCurrentRequest()
                self.onLoadFailure?("等待用量字段超时")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.readRetryInterval) { [weak self] in
                guard let self, requestID == self.requestID else { return }
                self.readPageText(requestID: requestID, attempt: attempt + 1)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === activeNavigation else { return }
        invalidateCurrentRequest()
        onLoadFailure?("网络加载失败：\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard navigation === activeNavigation else { return }
        invalidateCurrentRequest()
        onLoadFailure?("网络连接失败：\(error.localizedDescription)")
    }

    func windowWillClose(_ notification: Notification) {
        invalidateCurrentRequest()
    }

    private func invalidateCurrentRequest() {
        requestID = UUID()
        activeNavigation = nil
    }
}
