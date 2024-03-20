//
//  LazyAdContainerView.swift
//  DemoSwiftApp
//
//  Created by Konstantin Vasyliev on 14.03.2024.
//

import UIKit
import AudienzziOSSDK

// just test if view will display in view port
class LazyAdContainerView: VisibleView {
    private var isLazyLoadApear: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func detectVisible() {
        guard !isLazyLoadApear else { return }
        print("I AM VISIBLE: \(isVisible(view: self))")
        isLazyLoadApear = true
    }
    
}

private extension LazyAdContainerView {
    func isVisible(view: UIView) -> Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: view, inView: view.superview)
    }
}
