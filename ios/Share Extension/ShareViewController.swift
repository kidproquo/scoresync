// If you get no such module 'receive_sharing_intent' error.
// Go to Build Phases of your Runner target and
// move `Embed Foundation Extension` to the top of `Thin Binary`.
import UIKit
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    private var loadingContainerView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Completely replace the default view
        showLoadingIndicator()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure loading view stays on top
        if let container = loadingContainerView {
            self.view.bringSubviewToFront(container)
        }
    }

    // Use this method to return false if you don't want to redirect to host app automatically.
    // Default is true
    override func shouldAutoRedirect() -> Bool {
        return true
    }

    private func showLoadingIndicator() {
        // Remove all existing subviews
        self.view.subviews.forEach { $0.removeFromSuperview() }

        // Create a container view for the loading indicator
        let containerView = UIView(frame: self.view.bounds)
        containerView.backgroundColor = UIColor.systemBackground
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Create activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = UIColor.label
        activityIndicator.startAnimating()

        // Create label
        let label = UILabel()
        label.text = "Opening in Symph..."
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        // Add to container
        containerView.addSubview(activityIndicator)
        containerView.addSubview(label)

        // Add container to view
        self.view.addSubview(containerView)
        self.loadingContainerView = containerView

        // Setup constraints
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -20),

            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
        ])
    }

}
