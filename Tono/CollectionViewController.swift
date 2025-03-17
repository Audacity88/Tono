import UIKit
import CoreData

class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private var collectionView: UICollectionView!
    var context: NSManagedObjectContext! {
        didSet {
            if isViewLoaded {
                fetchTaggedObjects()
            }
        }
    }
    private var taggedObjects: [TaggedObject] = []
    private let reuseIdentifier = "TaggedObjectCell"
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupNavigationBar()
        if context != nil {
            fetchTaggedObjects()
        }
        
        // Add observer for newly saved objects
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleObjectSaved),
            name: Notification.Name("TaggedObjectSaved"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchTaggedObjects()
    }
    
    private func setupNavigationBar() {
        title = "My Collection"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Add edit button
        navigationItem.rightBarButtonItem = editButtonItem
        
        // Add sort button
        let sortButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: self, action: #selector(showSortOptions))
        navigationItem.leftBarButtonItem = sortButton
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let screenWidth = UIScreen.main.bounds.width
        let itemWidth = (screenWidth - 30) / 2 // 2 items per row with spacing
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth * 1.3) // Taller cells for labels
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TaggedObjectCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        // Add empty state view
        setupEmptyStateView()
        
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "camera.viewfinder"))
        imageView.tintColor = .systemGray
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "No objects in your collection yet"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .systemGray
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Explore your surroundings and tag objects to add them to your collection"
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        
        return view
    }()
    
    private func setupEmptyStateView() {
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func refreshData() {
        fetchTaggedObjects()
        collectionView.refreshControl?.endRefreshing()
    }
    
    @objc private func showSortOptions() {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Date Added (Newest First)", style: .default) { [weak self] _ in
            self?.sortObjects(by: .dateAdded)
        })
        
        alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default) { [weak self] _ in
            self?.sortObjects(by: .name)
        })
        
        alert.addAction(UIAlertAction(title: "Review Count", style: .default) { [weak self] _ in
            self?.sortObjects(by: .reviewCount)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private enum SortOption {
        case dateAdded
        case name
        case reviewCount
    }
    
    private func sortObjects(by option: SortOption) {
        switch option {
        case .dateAdded:
            taggedObjects.sort { $0.timestamp ?? Date() > $1.timestamp ?? Date() }
        case .name:
            taggedObjects.sort { $0.english ?? "" < $1.english ?? "" }
        case .reviewCount:
            taggedObjects.sort { $0.reviewCount > $1.reviewCount }
        }
        collectionView.reloadData()
    }
    
    private func fetchTaggedObjects() {
        taggedObjects = PersistenceController.shared.fetchTaggedObjects(context: context)
        
        // Debug info about fetched objects
        print("Fetched \(taggedObjects.count) tagged objects for collection view")
        for (index, object) in taggedObjects.enumerated() {
            let hasImage = object.image != nil && !(object.image?.isEmpty ?? true)
            let imageSize = object.image?.count ?? 0
            print("  Object \(index): \(object.english ?? "unknown") - Has image: \(hasImage) (Size: \(imageSize) bytes)")
        }
        
        collectionView.reloadData()
        
        // Show/hide empty state view
        emptyStateView.isHidden = !taggedObjects.isEmpty
    }
    
    @objc private func handleObjectSaved() {
        DispatchQueue.main.async { [weak self] in
            self?.fetchTaggedObjects()
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return taggedObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! TaggedObjectCell
        let taggedObject = taggedObjects[indexPath.item]
        cell.configure(with: taggedObject)
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let taggedObject = taggedObjects[indexPath.item]
        let detailVC = ObjectDetailViewController(taggedObject: taggedObject, context: context)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    // MARK: - Editing Support
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.allowsMultipleSelection = editing
        
        // Update cell appearance for editing mode
        for cell in collectionView.visibleCells {
            if let cell = cell as? TaggedObjectCell {
                cell.setEditing(editing)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        setEditing(true, animated: true)
    }
}

// MARK: - TaggedObjectCell

class TaggedObjectCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let translationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()
    
    private let reviewBadge: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray5.cgColor
        
        contentView.addSubview(imageView)
        contentView.addSubview(labelStack)
        contentView.addSubview(reviewBadge)
        
        labelStack.addArrangedSubview(nameLabel)
        labelStack.addArrangedSubview(translationLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),
            
            labelStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            labelStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            labelStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            labelStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            
            reviewBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            reviewBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            reviewBadge.widthAnchor.constraint(equalToConstant: 30),
            reviewBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with taggedObject: TaggedObject) {
        // Log debugging info
        let objectName = taggedObject.english ?? "unknown"
        let hasImageData = taggedObject.image != nil && !(taggedObject.image?.isEmpty ?? true)
        let imageDataSize = taggedObject.image?.count ?? 0
        print("Configuring cell for \(objectName) - Image data: \(hasImageData) (Size: \(imageDataSize) bytes)")
        
        if let imageData = taggedObject.image, !imageData.isEmpty {
            print("  Attempting to create UIImage for \(objectName) from \(imageData.count) bytes")
            
            // Set a placeholder immediately
            imageView.image = UIImage(systemName: "arrow.clockwise")
            imageView.tintColor = .systemBlue
            imageView.contentMode = .center
            
            // Use a background thread to create the image
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let startTime = CFAbsoluteTimeGetCurrent()
                let image = UIImage(data: imageData)
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                
                let success = image != nil
                print("  Image creation for \(objectName): \(success ? "SUCCESS" : "FAILED") in \(duration) seconds")
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let image = image {
                        self.imageView.image = image
                        self.imageView.contentMode = .scaleAspectFill
                        self.imageView.tintColor = nil
                        print("  Successfully displayed image for \(objectName)")
                    } else {
                        self.imageView.image = UIImage(systemName: "exclamationmark.triangle")
                        self.imageView.tintColor = .systemRed
                        self.imageView.contentMode = .center
                        print("  Failed to create/display image for \(objectName)")
                    }
                }
            }
        } else {
            print("  No image data for \(objectName)")
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .systemGray3
            imageView.contentMode = .center
        }
        
        nameLabel.text = taggedObject.english
        translationLabel.text = "\(taggedObject.chinese ?? "") (\(taggedObject.pinyin ?? ""))"
        
        // Configure review badge
        if let label = reviewBadge.subviews.first as? UILabel {
            label.text = "\(taggedObject.reviewCount)"
        }
        reviewBadge.isHidden = taggedObject.reviewCount == 0
    }
    
    func setEditing(_ editing: Bool) {
        // Add visual feedback for editing mode
        UIView.animate(withDuration: 0.2) {
            self.transform = editing ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.contentView.layer.borderWidth = editing ? 2 : 1
            self.contentView.layer.borderColor = editing ? UIColor.systemBlue.cgColor : UIColor.systemGray5.cgColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        nameLabel.text = nil
        translationLabel.text = nil
        reviewBadge.isHidden = true
    }
} 