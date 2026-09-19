import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let store: UsageStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let fiveHourItem = NSMenuItem(title: "5 小时已使用：—", action: nil, keyEquivalent: "")
    private let weeklyItem = NSMenuItem(title: "每周已使用：—", action: nil, keyEquivalent: "")
    private let statusItemRow = NSMenuItem(title: "等待首次刷新", action: nil, keyEquivalent: "")
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        super.init()
        configureMenu()
        bind()
    }

    private func configureMenu() {
        guard let button = statusItem.button else { return }
        button.title = "5h 已用 — · W 已用 —"
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        let menu = NSMenu()
        menu.addItem(fiveHourItem)
        menu.addItem(weeklyItem)
        menu.addItem(.separator())
        menu.addItem(statusItemRow)
        menu.addItem(.separator())
        menu.addItem(withTitle: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(withTitle: "登录 / 打开用量页面", action: #selector(login), keyEquivalent: "l")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func bind() {
        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in self?.render(snapshot) }
            .store(in: &cancellables)
        store.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.statusItemRow.title = state.description }
            .store(in: &cancellables)
    }

    private func render(_ snapshot: UsageSnapshot?) {
        guard let snapshot else { return }
        statusItem.button?.title = snapshot.menuTitle
        fiveHourItem.title = "5 小时已使用：\(snapshot.fiveHourPercent.map { "\($0)%" } ?? "—")"
        weeklyItem.title = "每周已使用：\(snapshot.weeklyPercent.map { "\($0)%" } ?? "—")"
    }

    @objc private func refresh() { store.refresh() }
    @objc private func login() { store.showLogin() }
    @objc private func quit() { NSApp.terminate(nil) }
}
