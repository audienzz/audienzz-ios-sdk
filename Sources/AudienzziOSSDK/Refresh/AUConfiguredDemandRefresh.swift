import Foundation
import UIKit

/// Preserves the configurable demand cadence of custom native, multiformat and fullscreen APIs.
/// These APIs hand the ad-server / renderer to the publisher, so their existing interval is a
/// demand interval. They do not infer a render failure or fast-retry from a Prebid result.
/// GAM display/native banners use AUBannerView's full Google completion lifecycle instead.
internal final class AUConfiguredDemandRefresh {
    private weak var view: AUAdView?
    private let scheduler: AURefreshScheduler
    private var operation: (() -> Void)?
    private var completed = false
    private var pending = false
    private var active = true
    private weak var pageViewController: UIViewController?
    private var pageToken: AnyObject?
    private var hadPage = false
    private(set) lazy var controller = AURefreshController(label: "configured-demand", scheduler: scheduler) { [weak self] _, _ in
        self?.operation?()
    }

    init(view: AUAdView, configuration: AUAdUnitConfiguration, scheduler: AURefreshScheduler = AUMainQueueRefreshScheduler()) {
        self.scheduler = scheduler
        self.view = view
        if let (page, _) = AUScreenAdCoordinator.shared.activeScreenAndName {
            hadPage = true
            if let vc = page as? UIViewController { pageViewController = vc } else { pageToken = page }
        }
        configuration.autorefreshIntervalObserver = { [weak self] in self?.controller.setIntervalMillis($0) }
        configuration.autorefreshPauseObserver = { [weak self] paused in
            guard let self else { return }
            if paused { self.controller.block(.publisher) }
            else { self.controller.unblock(.publisher, schedule: false); self.resume() }
        }
        controller.setIntervalMillis(configuration.autorefreshEventModel.autorefreshTime)
        if view.window == nil { controller.block(.detached) }
        if Audienzz.shared.isAppBackgrounded { controller.block(.appBackground) }
        Audienzz.shared.observeForegroundReimpression()
        AUScreenAdCoordinator.shared.registerConfigured(self)
    }

    /// The view retains only a weak-self operation; no timer or callback keeps its owner alive.
    func begin(_ operation: @escaping () -> Void) -> Int? {
        self.operation = operation
        guard !controller.isDestroyed, !controller.hasRequestInFlight else { return nil }
        let blocked = controller.blockReasons.contains {
            completed || ($0 != .detached && $0 != .notVisible)
        }
        guard active, !blocked, !Audienzz.shared.isAppBackgrounded,
              !Audienzz.shared.hasPendingForegroundReimpression else {
            pending = true
            return nil
        }
        pending = false
        return controller.onRequestStarted(completed ? .periodicRefresh : .firstLoad)
    }

    /// Return false for superseded callbacks so the publisher never receives another page's bid.
    func finish(_ generation: Int) -> Bool {
        guard !controller.isDestroyed, active, generation == controller.generation,
              controller.hasRequestInFlight else { return false }
        completed = true
        controller.onRequestCompleted(generationAtRequest: generation, success: true)
        return true
    }

    func viewport(visible: Bool) {
        guard view?.smartRefresh == true else { return }
        if visible { controller.unblock(.notVisible, schedule: false); resume() }
        else { controller.block(.notVisible) }
    }

    func attachmentChanged() {
        if view?.window == nil { controller.block(.detached) }
        else { controller.unblock(.detached, schedule: false); resume() }
    }

    func background() {
        controller.block(.appBackground)
        controller.invalidatePending()
        pending = operation != nil
    }

    func foreground() {
        guard !Audienzz.shared.hasPendingForegroundReimpression else { return }
        controller.unblock(.appBackground, schedule: false)
        resume()
    }

    func pageChanged(_ page: AnyObject) {
        let ownPage = pageToken ?? pageViewController
        active = hadPage && (ownPage === page ||
            ((ownPage as? NSObject)?.isEqual(page) == true))
        controller.invalidatePending()
        if active {
            controller.unblock(.pageInactive, schedule: false)
            if !Audienzz.shared.isAppBackgrounded { controller.unblock(.appBackground, schedule: false) }
            pending = operation != nil
            resume()
        } else { controller.block(.pageInactive) }
    }

    private func resume() {
        guard !controller.isDestroyed, active else { return }
        if pending {
            if !completed, view?.isLazyLoad == true, view?.isViewCurrentlyVisible != true {
                view?.isLazyLoaded = false
            } else { operation?() }
        } else { controller.scheduleNext() }
    }

    func destroy() {
        controller.destroy()
        operation = nil
        AUScreenAdCoordinator.shared.deregisterConfigured(self)
    }
}
