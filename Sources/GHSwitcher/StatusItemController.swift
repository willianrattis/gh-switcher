import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let store: AccountStore
    private let loginItem: LoginItem
    private let settings: AppSettings
    private let presentation = PanelPresentation()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = FloatingPanel()
    private var hostingView: SizingHostingView<AnyView>!
    private var settingsWindow: SettingsWindowController?
    private var mouseMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    /// Margem transparente para as sombras do vidro não serem cortadas.
    private let shadowInset: CGFloat = 16
    /// Distância entre a barra de menus e o primeiro elemento do painel.
    private let topGap: CGFloat = 8

    init(store: AccountStore, loginItem: LoginItem, settings: AppSettings) {
        self.store = store
        self.loginItem = loginItem
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            button.image = GitHubMark.image(size: 16)
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.$accounts
            .map { $0.first(where: \.active)?.login }
            .removeDuplicates()
            .combineLatest(settings.$showLoginInMenuBar)
            .sink { [weak self] login, showLogin in
                guard let button = self?.statusItem.button else { return }
                button.toolTip = "GH Switcher: " + (login ?? String(localized: "no active account"))
                button.title = showLogin ? (login.map { " " + $0 } ?? "") : ""
            }
            .store(in: &cancellables)

        let root = PanelView(store: store, settings: settings, presentation: presentation) { [weak self] in
            self?.openSettings()
        }
        .padding(shadowInset)
        hostingView = SizingHostingView(rootView: AnyView(root))
        hostingView.onSizeChange = { [weak self] in self?.layoutPanel() }
        panel.contentView = hostingView
        panel.delegate = self

        // Primeira execução sem gh ou sem contas: abre os Ajustes com as boas-vindas.
        store.$hasLoaded
            .first { $0 }
            .sink { [weak self] _ in
                guard let self, self.store.needsOnboarding else { return }
                self.openSettings()
            }
            .store(in: &cancellables)

        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["GHS_OPEN_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.open() }
        }
        if env["GHS_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openSettings() }
        }
        #endif
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            close()
            showContextMenu()
        } else {
            panel.isVisible ? close() : open()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit GH Switcher"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    func openSettings() {
        close()
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: store, loginItem: loginItem, settings: settings)
        }
        settingsWindow?.show()
    }

    func open() {
        loginItem.refresh()
        Task { await store.refresh() }

        // Segue a aparência da barra de menus (escura sobre papel de parede escuro),
        // como a Central de Controle.
        let menuBarAppearance = statusItem.button?.effectiveAppearance
        let isDark = menuBarAppearance?.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? true
        panel.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

        layoutPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            presentation.isShown = true
        }

        #if DEBUG
        if Demo.isEnabled { return }
        #endif
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    func close() {
        guard panel.isVisible else { return }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        statusItem.button?.highlight(false)
        withAnimation(.easeIn(duration: 0.12)) {
            presentation.isShown = false
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.panel.orderOut(nil) }
        })
    }

    /// Posiciona o painel sob o ícone, ancorado pelo topo e dentro da tela.
    private func layoutPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let size = hostingView.fittingSize
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, visible.minX - shadowInset + 8), visible.maxX - size.width + shadowInset - 8)
        let y = visible.maxY - topGap - size.height + shadowInset

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        #if DEBUG
        if Demo.isEnabled { return }
        #endif
        close()
    }
}
