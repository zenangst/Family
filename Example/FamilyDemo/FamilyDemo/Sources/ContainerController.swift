import UIKit
import Family_Mobile

class ContainerController: FamilyViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.white
    title = "Loading"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    performBatchUpdates(withDuration: 0, { _ in
      for x in 0..<25 {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .init(top: 10, left: 10, bottom: 10, right: 10)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.itemSize.height = 50

        let viewController = CollectionViewController(numberOfItemsInSection: 12 * 2, layout: layout)
        let background = x % 2 == 0
          ? UIColor.white
          : UIColor.lightGray.withAlphaComponent(0.5)
        viewController.view.backgroundColor = background
        viewController.collectionView.backgroundColor = background

        add(viewController)
        title = "Loaded \(x)"
      }
    }) { (_, _) in
      self.title = "All done!"
    }
  }
}

