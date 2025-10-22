import AudienzziOSSDK
import GoogleInteractiveMediaAds
import GoogleMobileAds
import UIKit

class TargetingTestingViewController: UIViewController {
    private enum Constants {
        static let prebidAdConfigId = "15624474"

        static let gamAdUnitId = "/96628199/testapp_publisher/medium_rectangle_banner"

        static let testAppStoreUrl = "https://apps.apple.com/app/id0000000000"

        static let bannerWidth = 300.0

        static let bannerHeight = 250.0
    }

    internal var bannerView: AUBannerView!

    // MARK: - IBOutlets
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var stackView: UIStackView!

    // Input fields
    @IBOutlet private weak var keyTextField: UITextField!
    @IBOutlet private weak var valueTextField: UITextField!
    @IBOutlet private weak var removeKeyTextField: UITextField!

    // Buttons
    @IBOutlet private weak var submitButton: UIButton!
    @IBOutlet private weak var removeButton: UIButton!
    @IBOutlet private weak var clearAllButton: UIButton!
    @IBOutlet private weak var requestAdButton: UIButton!

    // Ad display
    @IBOutlet private weak var adContainerView: UIView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardHandling()
        applyStoreUrlForTargeting()
    }

    // MARK: - IBActions
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard let key = keyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            showAlert(message: "Please enter a key")
            return
        }

        guard let value = valueTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            showAlert(message: "Please enter a value")
            return
        }

        if value.contains(",") {
            let valueArray =
            value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            AUTargeting.shared.addGlobalTargeting(key: key, values: Set(valueArray))
        } else {
            AUTargeting.shared.addGlobalTargeting(key: key, value: value)
        }

        AUTargeting.shared.addGlobalTargeting(key: key, value: value)

        keyTextField.text = ""
        valueTextField.text = ""

        showToast(message: "Added: \(key) = \(value)")
    }

    @IBAction func removeButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard let keyToRemove = removeKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !keyToRemove.isEmpty else {
            showAlert(message: "Please enter a key to remove values for")
            return
        }

        AUTargeting.shared.removeGlobalTargeting(key: keyToRemove)
        removeKeyTextField.text = ""
        showToast(message: "Removed key: \(keyToRemove)")
    }

    @IBAction func clearAllButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        AUTargeting.shared.clearGlobalTargeting()
        showToast(message: "All key-value pairs cleared")
    }

    @IBAction func requestAdButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        requestAd()
    }
}

// MARK: - UI Setup

private extension TargetingTestingViewController {
    func setupUI() {
        title = "Targeting Testing page"

        // Configure text fields
        setupTextFields()

        // Configure buttons
        setupButtons()
    }

    func setupTextFields() {
        [keyTextField, valueTextField, removeKeyTextField].forEach { textField in
            textField?.borderStyle = .roundedRect
            textField?.delegate = self
        }

        keyTextField.placeholder = "Enter key"
        valueTextField.placeholder = "Enter value"
        removeKeyTextField.placeholder = "Enter key to remove"
    }

    func setupButtons() {
        // Submit button
        submitButton.backgroundColor = .systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 8

        // Remove button
        removeButton.backgroundColor = .systemBlue
        removeButton.setTitleColor(.white, for: .normal)
        removeButton.layer.cornerRadius = 8

        // Clear all button
        clearAllButton.backgroundColor = .systemRed
        clearAllButton.setTitleColor(.white, for: .normal)
        clearAllButton.layer.cornerRadius = 8

        // Request ad button
        requestAdButton.backgroundColor = .systemGreen
        requestAdButton.setTitleColor(.white, for: .normal)
        requestAdButton.layer.cornerRadius = 8
    }
}

// MARK: - Ad Management

private extension TargetingTestingViewController {
    func requestAd() {
        // Clear previous ad
        adContainerView.subviews.forEach { $0.removeFromSuperview() }

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: CGSize(width: Constants.bannerWidth, height: Constants.bannerHeight))
        )
        gamBanner.adUnitID = Constants.gamAdUnitId
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerView = AUBannerView(
            configId: Constants.prebidAdConfigId,
            adSize: CGSize(width: Constants.bannerWidth, height: Constants.bannerHeight),
            adFormats: [.banner],
            isLazyLoad: false
        )
        bannerView.bannerParameters = AUBannerParameters()
        bannerView.frame = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: self.view.frame.width, height: Constants.bannerHeight)
        )
        bannerView.backgroundColor = .clear
        adContainerView.addSubview(bannerView)

        let handler = AUBannerEventHandler(
            adUnitId: Constants.gamAdUnitId,
            gamView: gamBanner
        )

        bannerView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: handler
        )

        bannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: adContainerView.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: adContainerView.centerYAnchor),
        ])
    }
}

// MARK: - Targeting examples

private extension TargetingTestingViewController {
    func applyStoreUrlForTargeting() {
        AUTargeting.shared.storeURL = Constants.testAppStoreUrl
    }
}

// MARK: - Helper Methods

private extension TargetingTestingViewController {
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showToast(message: String) {
        // Simple toast implementation
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.numberOfLines = 0

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            toastLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            toastLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])

        UIView.animate(
            withDuration: 0.3,
            animations: {
                toastLabel.alpha = 1.0
            }
        ) { _ in
            UIView.animate(
                withDuration: 0.3,
                delay: 2.0,
                options: [],
                animations: {
                    toastLabel.alpha = 0.0
                }
            ) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}

// MARK: - Keyboard Handling

private extension TargetingTestingViewController {
    func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.height
            scrollView.contentInset.bottom = keyboardHeight
            scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate
extension TargetingTestingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == keyTextField {
            valueTextField.becomeFirstResponder()
        } else if textField == valueTextField {
            submitButtonTapped(submitButton)
        } else if textField == removeKeyTextField {
            removeButtonTapped(removeButton)
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

extension TargetingTestingViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else {
            return
        }
        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { size in
                bannerView.resize(adSizeFor(cgSize: size))
            },
            failure: { [weak self] (error) in
                self?.showAlert(message: "Error resizing ad: \(error.localizedDescription)")
            }
        )
    }

    func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        print("GAM did fail to receive ad with error: \(error)")

        showAlert(message: "Error loading ad: \(error.localizedDescription)")
    }
}
