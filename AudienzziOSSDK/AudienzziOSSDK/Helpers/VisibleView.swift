//
//  VisibleView.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 14.03.2024.
//

import UIKit

extension UIView {
    func getAllSuperviews() -> [UIView]? {
        var superviews: [UIView] = []
        
        guard let superView = self.superview else {
            return nil
        }
        
        superviews.append(superView)
        
        guard let subViews = superView.getAllSuperviews() else {
            return superviews
        }
        
        superviews.append(contentsOf: subViews)
        return superviews
    }
}

open class VisibleView: UIView {
    
    open override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window != nil {
            observeSuperviewsOnOffsetChange()
        } else {
            removeAsSuperviewObserver()
        }
    }
    
    open func detectVisible() {
    }
    
    private func observeSuperviewsOnOffsetChange() {
        guard let superviews = self.getAllSuperviews() else { return }
        for superview in superviews {
            if superview.responds(to: #selector(getter: UIScrollView.contentOffset)) {
                superview.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
            }
        }
    }
    
    private func removeAsSuperviewObserver() {
        guard let superviews = self.getAllSuperviews() else { return }
        for superview in superviews {
            superview.removeObserver(self, forKeyPath: "contentOffset")
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            checkIfFrameIsVisible()
        }
    }
    
    private func checkIfFrameIsVisible() {
        guard let myWindow = self.window else { return }
        let myFrameToWindow = myWindow.convert(self.frame, from: self)
        let myPointToWindow = myWindow.convert(self.frame.origin, from: self.superview)
        
        if myFrameToWindow.size.width == 0 && myFrameToWindow.size.height == 0 {
            return
        }
    
        if CGRectContainsPoint(myWindow.frame, myPointToWindow) {
            detectVisible()
        }
    }
}
