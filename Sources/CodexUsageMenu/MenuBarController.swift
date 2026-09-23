import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let store: UsageStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let fiveHourItem = NSMenuItem(title: "5 小时已使用：—", action: nil, keyEquivalent: "")
    private let weeklyItem = NSMenuItem(title: "每周已使用：—", action: nil, keyEquivalent: "")
    private let displayModeItem = NSMenuItem(title: "显示剩余", action: #selector(toggleDisplayMode), keyEquivalent: "")
    private let statusItemRow = NSMenuItem(title: "等待首次刷新", action: nil, keyEquivalent: "")
    private var displayMode: UsageDisplayMode = .used
    private var latestSnapshot: UsageSnapshot?
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
        menu.addItem(displayModeItem)
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
        latestSnapshot = snapshot
        statusItem.button?.title = displayMode.menuTitle(
            fiveHourUsedPercent: snapshot?.fiveHourPercent,
            weeklyUsedPercent: snapshot?.weeklyPercent
        )
        fiveHourItem.title = displayMode.detailTitle(
            period: "5 小时",
            usedPercent: snapshot?.fiveHourPercent
        )
        weeklyItem.title = displayMode.detailTitle(
            period: "每周",
            usedPercent: snapshot?.weeklyPercent
        )
        displayModeItem.title = displayMode.toggleTitle
    }

    @objc private func toggleDisplayMode() {
        displayMode = displayMode.next
        render(latestSnapshot)
    }

    @objc private func refresh() { store.refresh() }
    @objc private func login() { store.showLogin() }
    @objc private func quit() { NSApp.terminate(nil) }
}
