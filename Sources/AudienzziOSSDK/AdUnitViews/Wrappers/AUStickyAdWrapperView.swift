import UIKit

/// Wraps an ad view and keeps it sticky within a reserved area as the user scrolls.
///
/// Reserve ``maxHeight`` points in your layout. As the user scrolls past the wrapper,
/// the child ad view slides within the reserved area, staying visible for as long
/// as possible before scrolling off screen.
///
/// The sticky behaviour mirrors the Flutter ``AudienzzStickyAdWrapper`` widget.
///
/// **Basic usage**
/// ```swift
/// let stickyWrapper = AUStickyAdWrapperView(
///     adView: myBannerView,
///     maxHeight: 450,
///     scrollView: scrollView
/// )
/// containerView.addSubview(stickyWrapper)
/// // Add Auto Layout constraints to stickyWrapper as you would any UIView.
/// // Its intrinsic height is maxHeight — you do not need a height constraint.
/// ```
///
/// **With backend-controlled dimensions**
/// ```swift
/// // Pass the same adConfigId used by the ad view. The SDK reads stickyMaxHeight
/// // and stickyTopOffset from the cached remote config automatically.
/// // Publisher-supplied maxHeight / stickyTopOffset always win over backend values.
/// let stickyWrapper = AUStickyAdWrapperView(
///     adView: myBannerView,
///     adConfigId: "118",
///     scrollView: scrollView
/// )
/// ```
public final class AUStickyAdWrapperView: UIView {

    // MARK: - Public Properties

    /// Total height reserved in the layout for the sticky region.
    ///
    /// Pass `nil` (or omit) to let the backend-configured value or the SDK default (600 pt) apply.
    /// A non-nil value always wins over the backend setting.
    public var maxHeight: CGFloat? {
        didSet {
            let h = effectiveMaxHeight
            heightConstraint?.constant = h
            if let adView = childView as? AUAdView, let childHeightConstraint {
                childHeightConstraint.constant = min(adView.adSize.height, h)
            }
            updatePosition()
        }
    }

    /// Y offset (points) from the top of the scroll viewport where the ad should stick.
    ///
    /// Pass `nil` (or omit) to use the backend-configured value. If the backend also has
    /// no value, the scroll view's top safe-area inset is used.
    /// A non-nil value always wins over the backend setting.
    public var stickyTopOffset: CGFloat?

    /// Whether sticky behaviour is active. When `false` the child stays at position 0.
    public var isEnabled: Bool = true {
        didSet { updatePosition() }
    }

    /// Remote ad-unit config ID. When set the SDK reads `stickyMaxHeight` and
    /// `stickyTopOffset` from the cached remote config and applies them as
    /// fallback values (publisher overrides still take precedence).
    public var adConfigId: String? {
        didSet { applyRemoteConfig() }
    }

    // MARK: - Private Properties

    private weak var scrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?

    private weak var childView: UIView?
    private var topConstraint: NSLayoutConstraint?
    private var childHeightConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var lastAppliedOffset: CGFloat = .greatestFiniteMagnitude

    /// Backing storage for remote-config-derived values.
    private var remoteMaxHeight: CGFloat?
    private var remoteStickyTopOffset: CGFloat?

    // MARK: - Computed Effective Values

    /// Resolved max height: publisher override → remote config → SDK default.
    private var effectiveMaxHeight: CGFloat {
        maxHeight ?? remoteMaxHeight ?? 600
    }

    /// Resolved sticky top offset: publisher override → remote config → nil (uses safe-area).
    private var effectiveStickyTopOffset: CGFloat? {
        stickyTopOffset ?? remoteStickyTopOffset
    }

    // MARK: - Init

    /// Creates a sticky ad wrapper.
    /// - Parameters:
    ///   - adView: The ad view to wrap. Added as a subview automatically.
    ///   - adConfigId: Optional remote ad-unit config ID. When provided the SDK reads
    ///                 `stickyMaxHeight` and `stickyTopOffset` from the cached remote config.
    ///   - maxHeight: Height reserved in the layout. Pass `nil` to use the backend value or 600.
    ///   - scrollView: The scroll view that drives sticky behaviour.
    ///                 Call ``attachToScrollView(_:)`` later if not available at init time.
    public init(
        adView: UIView,
        adConfigId: String? = nil,
        maxHeight: CGFloat? = nil,
        scrollView: UIScrollView? = nil
    ) {
        self.maxHeight = maxHeight
        self.adConfigId = adConfigId
        super.init(frame: .zero)
        commonInit()
        applyRemoteConfig()
        setupChild(adView)
        if let sv = scrollView {
            attachToScrollView(sv)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updatePosition()
    }

    deinit {
        detachFromScrollView()
    }

    // MARK: - Public Methods

    /// Attaches the wrapper to a `UIScrollView` to receive scroll events.
    public func attachToScrollView(_ scrollView: UIScrollView) {
        detachFromScrollView()
        self.scrollView = scrollView
        scrollObservation = scrollView.observe(\.contentOffset, options: .new) { [weak self] _, _ in
            self?.updatePosition()
        }
        updatePosition()
    }

    /// Detaches from the current scroll view, stopping scroll-driven position updates.
    public func detachFromScrollView() {
        scrollObservation?.invalidate()
        scrollObservation = nil
        scrollView = nil
    }

    // MARK: - Private

    private func commonInit() {
        clipsToBounds = true
        backgroundColor = .clear
    }

    /// Reads remote config values for the current `adConfigId` and caches them.
    /// Safe to call before `setupChild` — layout constraints are updated if already created.
    private func applyRemoteConfig() {
        guard let adConfigId else {
            remoteMaxHeight = nil
            remoteStickyTopOffset = nil
            return
        }
        let config = AudienzzRemoteConfig.shared.remoteConfig(for: adConfigId)?.config
        remoteMaxHeight = config?.stickyMaxHeight.map { CGFloat($0) }
        remoteStickyTopOffset = config?.stickyTopOffset.map { CGFloat($0) }

        // Refresh constraints if already laid out.
        let h = effectiveMaxHeight
        heightConstraint?.constant = h
        if let adView = childView as? AUAdView, let childHeightConstraint {
            childHeightConstraint.constant = min(adView.adSize.height, h)
        }
        updatePosition()
    }

    private func setupChild(_ view: UIView) {
        childView = view
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        let h = effectiveMaxHeight
        let top = view.topAnchor.constraint(equalTo: topAnchor)
        let height = self.heightAnchor.constraint(equalToConstant: h)

        NSLayoutConstraint.activate([
            top,
            height,
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        if let adView = view as? AUAdView, adView.adSize.height > 0 {
            let childHeight = view.heightAnchor.constraint(
                equalToConstant: min(adView.adSize.height, h)
            )
            childHeight.isActive = true
            childHeightConstraint = childHeight
        }

        topConstraint = top
        heightConstraint = height
    }

    private func updatePosition() {
        guard isEnabled, let scrollView else {
            applyChildOffset(0)
            return
        }

        // Convert into the scroll view's content coordinate space, then shift
        // by contentOffset to get position inside the visible viewport.
        let frameInScrollView = convert(bounds, to: scrollView)

        let topOffset = effectiveStickyTopOffset ?? scrollView.safeAreaInsets.top
        let childHeight = resolvedChildHeight()
        let maxH = effectiveMaxHeight

        // wrapperTop/Bottom relative to the visible viewport (not content)
        let wrapperTop = frameInScrollView.minY - scrollView.contentOffset.y
        let wrapperBottom = wrapperTop + bounds.height

        // Fast path: skip off-screen wrappers to reduce per-scroll cost.
        let viewportHeight = scrollView.bounds.height
        if wrapperBottom < -viewportHeight || wrapperTop > viewportHeight * 2 {
            return
        }

        let maxTop = max(0, bounds.height - childHeight)

        let newTop: CGFloat
        if wrapperTop >= topOffset {
            // Wrapper is fully below viewport top — child sits at start of wrapper
            newTop = 0
        } else if wrapperBottom <= topOffset + childHeight {
            // Wrapper's bottom has passed the sticky threshold — child at max position
            newTop = maxTop
        } else {
            // Wrapper is partially in view — slide child to keep it on screen
            newTop = topOffset - wrapperTop
        }

        let clamped = min(max(newTop, 0), maxTop)
        _ = maxH  // referenced via effectiveMaxHeight in resolvedChildHeight
        applyChildOffset(clamped)
    }

    private func resolvedChildHeight() -> CGFloat {
        let maxH = effectiveMaxHeight
        guard let childView else { return maxH }

        if childView.bounds.height > 0 {
            return childView.bounds.height
        }

        let intrinsic = childView.intrinsicContentSize.height
        if intrinsic > 0, intrinsic != UIView.noIntrinsicMetric {
            return min(intrinsic, maxH)
        }

        if let adView = childView as? AUAdView, adView.adSize.height > 0 {
            return min(adView.adSize.height, maxH)
        }

        return maxH
    }

    private func applyChildOffset(_ offset: CGFloat) {
        guard abs(offset - lastAppliedOffset) > 0.5 else { return }
        lastAppliedOffset = offset

        // Transform avoids layout passes that would happen on each constraint change.
        childView?.transform = CGAffineTransform(translationX: 0, y: offset)
    }
}
