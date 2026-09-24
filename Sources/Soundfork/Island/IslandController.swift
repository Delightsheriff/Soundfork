import AppKit
import SwiftUI

/// Shows and hides the island: positioning, open/close animation timing, and the ways to dismiss it
/// (click outside, Esc, clicking the menu-bar icon again).
@MainActor
final class IslandController {
    static let panelSize = CGSize(width: 480, height: 760)

    let model: IslandModel
    private let panel = IslandPanel()
    private var hosting: NSHostingView<IslandView>?
    private var monitors: [Any] = []
    private var hoverTimer: Timer?
    private var dwellSince: Date?
    private var awaySince: Date?
    private var openedByHover = false
    private var closeWork: DispatchWorkItem?
    /// The island's frame inside the panel, in SwiftUI (top-left origin) coordinates, reported by the view.
    private var islandFrame: CGRect = .zero

    var isOpen: Bool { model.isOpen }

    init(model: IslandModel) {
        self.model = model
    }

    func toggle(on screen: NSScreen?) {
        isOpen ? close() : open(on: screen)
    }

    func open(on screen: NSScreen?) {
        guard !isOpen, let screen = screen ?? NSScreen.main else { return }
        closeWork?.cancel()
        let notch = NotchGeometry(screen: screen)

        let view = IslandView(model: model, notch: notch.size, onIslandFrame: { [weak self] in self?.islandFrame = $0 })
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.sizingOptions = []
            panel.contentView = hosting
            self.hosting = hosting
        }
        panel.setFrame(notch.panelFrame(width: Self.panelSize.width, height: Self.panelSize.height), display: false)

        model.startLiveUpdates()
        panel.orderFrontRegardless()
        panel.makeKey()
        openedByHover = false
        awaySince = nil
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { model.isOpen = true }
        installDismissMonitors()
    }

    func close() {
        guard isOpen else { return }
        removeDismissMonitors()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            model.isOpen = false
            model.showOtherApps = false
            model.expandedPicker = nil
        }
        model.stopLiveUpdates()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.isOpen else { return }
            self.panel.orderOut(nil)
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    // MARK: Dismissal

    private func installDismissMonitors() {
        removeDismissMonitors()
        // Clicks in other apps.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) { monitors.append(global) }

        // Clicks on the panel's transparent area around the island, and Esc.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            // Local monitors run on the main thread; the event never leaves it.
            nonisolated(unsafe) let event = event
            let consumed = MainActor.assumeIsolated { self?.handleLocal(event) ?? false }
            return consumed ? nil : event
        }) { monitors.append(local) }
    }

    /// Returns true if the event was used to dismiss the island.
    private func handleLocal(_ event: NSEvent) -> Bool {
        if event.type == .keyDown {
            guard event.keyCode == 53 else { return false }
            if model.expandedPicker != nil {
                withAnimation(IslandView.pickerSpring) { model.expandedPicker = nil }
            } else {
                close()
            }
            return true
        }
        guard event.window === panel, !islandContains(event.locationInWindow) else { return false }
        close()
        return true
    }

    private func removeDismissMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func islandContains(_ windowPoint: CGPoint) -> Bool {
        // AppKit window coordinates have a bottom-left origin; SwiftUI's frame is top-left.
        let flipped = CGPoint(x: windowPoint.x, y: panel.frame.height - windowPoint.y)
        return islandFrame.insetBy(dx: -4, dy: -4).contains(flipped)
    }

    // MARK: Open on notch hover

    /// Polls the pointer 10×/s rather than using mouse-moved monitors: works over the menu bar and full-screen apps,
    /// and costs nothing measurable. Scheduled in the default run-loop mode only, so it pauses while a menu is open.
    func setHoverToOpen(_ enabled: Bool) {
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard enabled else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        RunLoop.main.add(timer, forMode: .default)
        hoverTimer = timer
    }

    private func pollPointer() {
        let location = NSEvent.mouseLocation
        if isOpen {
            guard openedByHover else { return }
            // Hover-opened islands close once the pointer has been away from them for a moment.
            // Never while a button is held: a slider drag can wander outside the island.
            if NSEvent.pressedMouseButtons != 0 || islandScreenFrame().insetBy(dx: -24, dy: -24).contains(location) {
                awaySince = nil
            } else if let awaySince {
                if Date.now.timeIntervalSince(awaySince) > 0.5 { close() }
            } else {
                awaySince = .now
            }
            return
        }
        guard let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: 0, dy: -1).contains(location) }),
              hotZone(on: screen).contains(location) else {
            dwellSince = nil
            return
        }
        // Short dwell so sweeping the pointer across the top of the screen doesn't pop it open.
        if let dwellSince {
            if Date.now.timeIntervalSince(dwellSince) >= 0.15 {
                self.dwellSince = nil
                open(on: screen)
                openedByHover = true
            }
        } else {
            dwellSince = .now
        }
    }

    /// The notch plus a little slack, reaching past the top edge (the pointer rests at y == maxY there).
    private func hotZone(on screen: NSScreen) -> CGRect {
        NotchGeometry(screen: screen).notchRect.insetBy(dx: -10, dy: -2).offsetBy(dx: 0, dy: 2)
    }

    private func islandScreenFrame() -> CGRect {
        CGRect(x: panel.frame.minX + islandFrame.minX,
               y: panel.frame.maxY - islandFrame.maxY,
               width: islandFrame.width,
               height: islandFrame.height)
    }
}
