import UIKit
import Family

class ContainerController: FamilyViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.white
    title = "Loading"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    performBatchUpdates(withDuration: 0.125, { _ in
      for x in 0..<1000 {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .init(top: 10, left: 10, bottom: 0, right: 10)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.itemSize.height = 50

        let viewController = CollectionViewController(numberOfItemsInSection: 12, layout: layout)
        viewController.view.backgroundColor = .white
        viewController.collectionView.backgroundColor = .white

        add(viewController)
        title = "Loaded \(x)"
        CATransaction.flush()
      }
    }) { (_) in
      self.title = "All done!"
    }
  }
}

