import AppKit
import SwiftUI

/// Janela transparente e sem borda: os blocos de vidro flutuam sobre a área de trabalho,
/// como na Central de Controle.
final class FloatingPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        (delegate as? StatusItemController)?.close()
    }
}

/// NSHostingView que avisa quando o tamanho do conteúdo SwiftUI muda.
final class SizingHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }
}

@MainActor
final class PanelPresentation: ObservableObject {
    @Published var isShown = false
}
