import Social
import SwiftUI
import Combine

class ShareViewController: UIViewController {
    private var coordinator = ShareCoordinator()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("ShareViewController viewDidLoad called")
        
        guard let extensionContext = extensionContext else {
            print("extensionContext is nil")
            return
        }
        
        print("Initializing ShareView with model container")
        let shareView = ShareView(extensionContext: extensionContext, coordinator: coordinator)
            .modelContainer(skateSessionExtensionModelContainer)
        
        let hostingController = UIHostingController(rootView: shareView)
        
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        coordinator.$shouldDismiss.sink { [weak self] shouldDismiss in
            print("shouldDismiss: \(shouldDismiss)")
            if shouldDismiss {
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }.store(in: &cancellables)
        
        coordinator.$shouldSave.sink { [weak self] shouldSave in
            print("shouldSave: \(shouldSave)")
            if shouldSave {
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }.store(in: &cancellables)
    }
}
