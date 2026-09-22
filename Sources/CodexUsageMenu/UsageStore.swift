import AppKit
import Combine
import Foundation
import WebKit

enum UsageNavigationDecision: Equatable {
    case ignore
    case readUsage
    case needsLogin
    case unknownHost
}

enum UsageNavigationPolicy {
    static func shouldObserveUsage(in url: URL?) -> Bool {
        guard let url, let host = url.host else { return false }
        return matches(host: host, domain: "chatgpt.com")
    }

    static func decision(for url: URL?, matchesCurrentRequest: Bool) -> UsageNavigationDecision {
        guard let url, let host = url.host else { return .ignore }

        let acceptedHosts = ["chatgpt.com", "auth.openai.com", "openai.com"]
        guard acceptedHosts.contains(where: { matches(host: host, domain: $0) }) else {
            return matchesCurrentRequest ? .unknownHost : .ignore
        }

        if matches(host: host, domain: "chatgpt.com"), url.path.contains("/codex/settings/usage") {
            // 用户完成登录时会产生新的导航；此时已不再持有初始请求的 WKNavigation。
            return .readUsage
        }

        return matchesCurrentRequest ? .needsLogin : .ignore
    }

    private static func matches(host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }
}

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
    private let pageTextScript = """
    (() => {
      const bodyText = document.body ? document.body.innerText : '';
      const aria = Array.from(document.querySelectorAll('[aria-label]'))
        .map(node => node.getAttribute('aria-label'))
        .filter(Boolean)
        .join('\\n');
      const text = [bodyText, aria].join('\\n');
      const ready = /(?:5\\s*hour|5h|five-hour|weekly|week|7\\s*day|seven-day|5\\s*小时|每周)/i.test(text);
      return { ready, text };
    })();
    """
    private var requestID = UUID()
    private weak var activeNavigation: WKNavigation?
    private var pageObservationTimer: Timer?
    private var pageObservationID = UUID()
    private var pageProbeInFlight = false

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
        startObservingVisiblePage()
        if webView.url == nil { loadUsagePage() }
    }

    func loadUsagePage() {
        requestID = UUID()
        activeNavigation = webView.load(
            URLRequest(url: usageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch UsageNavigationPolicy.decision(
            for: webView.url,
            matchesCurrentRequest: navigation === activeNavigation
        ) {
        case .ignore:
            return
        case .unknownHost:
            invalidateCurrentRequest()
            onLoadFailure?("登录页面跳转到了未知域名")
        case .needsLogin:
            invalidateCurrentRequest()
            onLoginRequired?()
        case .readUsage:
            readPageText(requestID: requestID, attempt: 1)
        }
    }

    private func readPageText(requestID: UUID, attempt: Int) {
        evaluateUsagePageText { [weak self] text in
            guard let self, requestID == self.requestID else { return }

            if let text {
                self.stopObservingVisiblePage()
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

    private func startObservingVisiblePage() {
        guard pageObservationTimer == nil else { return }

        let observationID = UUID()
        pageObservationID = observationID
        observeVisiblePage(observationID: observationID)

        let timer = Timer(timeInterval: readRetryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.observeVisiblePage(observationID: observationID)
            }
        }
        pageObservationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func observeVisiblePage(observationID: UUID) {
        guard observationID == pageObservationID,
              loginWindow.isVisible,
              !pageProbeInFlight,
              UsageNavigationPolicy.shouldObserveUsage(in: webView.url) else {
            return
        }

        pageProbeInFlight = true
        evaluateUsagePageText { [weak self] text in
            guard let self else { return }
            guard observationID == self.pageObservationID else { return }
            self.pageProbeInFlight = false
            guard let text else { return }

            self.stopObservingVisiblePage()
            self.invalidateCurrentRequest()
            self.onPageText?(text)
        }
    }

    private func stopObservingVisiblePage() {
        pageObservationTimer?.invalidate()
        pageObservationTimer = nil
        pageObservationID = UUID()
        pageProbeInFlight = false
    }

    private func evaluateUsagePageText(completion: @escaping (String?) -> Void) {
        webView.evaluateJavaScript(pageTextScript) { result, error in
            guard error == nil,
                  let response = result as? [String: Any],
                  response["ready"] as? Bool == true,
                  let text = response["text"] as? String else {
                completion(nil)
                return
            }
            completion(text)
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
        stopObservingVisiblePage()
        invalidateCurrentRequest()
    }

    private func invalidateCurrentRequest() {
        requestID = UUID()
        activeNavigation = nil
    }
}
