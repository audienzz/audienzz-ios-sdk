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
public final class AUStickyAdWrapperView: UIView {

    // MARK: - Public Properties

    /// Total height reserved in the layout for the sticky region. Defaults to 600.
    public var maxHeight: CGFloat = 600 {
        didSet {
            heightConstraint?.constant = maxHeight
            if
                let adView = childView as? AUAdView,
                let childHeightConstraint
            {
                childHeightConstraint.constant = min(adView.adSize.height, maxHeight)
            }
            updatePosition()
        }
    }

    /// Y offset (points) from the top of the scroll viewport where the ad should stick.
    /// If `nil`, the scroll view's top safe-area inset is used.
    public var stickyTopOffset: CGFloat?

    /// Whether sticky behaviour is active. When `false` the child stays at position 0.
    public var isEnabled: Bool = true {
        didSet { updatePosition() }
    }

    // MARK: - Private Properties

    private weak var scrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?

    private weak var childView: UIView?
    private var topConstraint: NSLayoutConstraint?
    private var childHeightConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var lastAppliedOffset: CGFloat = .greatestFiniteMagnitude

    // MARK: - Init

    /// Creates a sticky ad wrapper.
    /// - Parameters:
    ///   - adView: The ad view to wrap. Added as a subview automatically.
    ///   - maxHeight: Height reserved in the layout. Defaults to 600.
    ///   - scrollView: The scroll view that drives sticky behaviour.
    ///                 Call ``attachToScrollView(_:)`` later if not available at init time.
    public init(adView: UIView, maxHeight: CGFloat = 600, scrollView: UIScrollView? = nil) {
        self.maxHeight = maxHeight
        super.init(frame: .zero)
        commonInit()
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

    private func setupChild(_ view: UIView) {
        childView = view
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        let top = view.topAnchor.constraint(equalTo: topAnchor)
        let height = self.heightAnchor.constraint(equalToConstant: maxHeight)

        NSLayoutConstraint.activate([
            top,
            height,
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        if let adView = view as? AUAdView, adView.adSize.height > 0 {
            let childHeight = view.heightAnchor.constraint(
                equalToConstant: min(adView.adSize.height, maxHeight)
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

        let topOffset = stickyTopOffset ?? scrollView.safeAreaInsets.top
        let childHeight = resolvedChildHeight()

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
        applyChildOffset(clamped)
    }

    private func resolvedChildHeight() -> CGFloat {
        guard let childView else { return maxHeight }

        if childView.bounds.height > 0 {
            return childView.bounds.height
        }

        let intrinsic = childView.intrinsicContentSize.height
        if intrinsic > 0, intrinsic != UIView.noIntrinsicMetric {
            return min(intrinsic, maxHeight)
        }

        if let adView = childView as? AUAdView, adView.adSize.height > 0 {
            return min(adView.adSize.height, maxHeight)
        }

        return maxHeight
    }

    private func applyChildOffset(_ offset: CGFloat) {
        guard abs(offset - lastAppliedOffset) > 0.5 else { return }
        lastAppliedOffset = offset

        // Transform avoids layout passes that would happen on each constraint change.
        childView?.transform = CGAffineTransform(translationX: 0, y: offset)
    }
}
