//
//  ExamplesViewController.swift
//  DemoSwiftApp
//
//  Created by Konstantin Vasyliev on 11.03.2024.
//

import UIKit

class ExamplesViewController: UIViewController {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet private weak var adContainerView: UIView!
    @IBOutlet private weak var lazyAdContainerView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black
    }
}

extension ExamplesViewController: UIScrollViewDelegate {
}
