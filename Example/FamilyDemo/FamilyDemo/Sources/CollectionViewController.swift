import UIKit

class CollectionViewController: UICollectionViewController {
  let numberOfItemsInSection: Int

  init(numberOfItemsInSection: Int, layout: UICollectionViewLayout) {
    self.numberOfItemsInSection = numberOfItemsInSection
    super.init(collectionViewLayout: layout)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    collectionView.register(Cell.self, forCellWithReuseIdentifier: "Cell")
  }

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return numberOfItemsInSection
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    cell.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
    return cell
  }
}
