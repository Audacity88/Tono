import UIKit
import CoreData
import AVFoundation

class ObjectDetailViewController: UIViewController {
    private let taggedObject: TaggedObject
    private let context: NSManagedObjectContext
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // We'll use pre-rotated images instead of transforming the view
        return imageView
    }()
    
    private let chineseLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .red
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pinyinLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24)
        label.textColor = .orange
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let englishLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pronunciationButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let reviewInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let reviewInfoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    
    init(taggedObject: TaggedObject, context: NSManagedObjectContext) {
        self.taggedObject = taggedObject
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureViews()
        setupNavigationBar()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        title = taggedObject.english
        navigationItem.largeTitleDisplayMode = .never
        
        // Add edit button
        let editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped))
        navigationItem.rightBarButtonItem = editButton
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(imageView)
        contentView.addSubview(chineseLabel)
        contentView.addSubview(pinyinLabel)
        contentView.addSubview(englishLabel)
        contentView.addSubview(pronunciationButton)
        contentView.addSubview(reviewInfoView)
        reviewInfoView.addSubview(reviewInfoStack)
        
        pronunciationButton.addTarget(self, action: #selector(pronounceTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            chineseLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            chineseLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            pinyinLabel.topAnchor.constraint(equalTo: chineseLabel.bottomAnchor, constant: 8),
            pinyinLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            englishLabel.topAnchor.constraint(equalTo: pinyinLabel.bottomAnchor, constant: 8),
            englishLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            pronunciationButton.topAnchor.constraint(equalTo: englishLabel.bottomAnchor, constant: 20),
            pronunciationButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pronunciationButton.widthAnchor.constraint(equalToConstant: 50),
            pronunciationButton.heightAnchor.constraint(equalToConstant: 50),
            
            reviewInfoView.topAnchor.constraint(equalTo: pronunciationButton.bottomAnchor, constant: 20),
            reviewInfoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            reviewInfoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            reviewInfoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            reviewInfoStack.topAnchor.constraint(equalTo: reviewInfoView.topAnchor, constant: 16),
            reviewInfoStack.leadingAnchor.constraint(equalTo: reviewInfoView.leadingAnchor, constant: 16),
            reviewInfoStack.trailingAnchor.constraint(equalTo: reviewInfoView.trailingAnchor, constant: -16),
            reviewInfoStack.bottomAnchor.constraint(equalTo: reviewInfoView.bottomAnchor, constant: -16)
        ])
    }
    
    private func configureViews() {
        // Configure image view
        if let imageData = taggedObject.image {
            // Load and rotate the image
            if let originalImage = UIImage(data: imageData) {
                // Create context for rotation
                UIGraphicsBeginImageContextWithOptions(CGSize(width: originalImage.size.height, height: originalImage.size.width), false, originalImage.scale)
                if let context = UIGraphicsGetCurrentContext() {
                    // Rotate 90 degrees counterclockwise
                    context.translateBy(x: 0, y: originalImage.size.width)
                    context.rotate(by: -CGFloat.pi / 2)
                    originalImage.draw(at: CGPoint.zero)
                    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    imageView.image = rotatedImage
                } else {
                    imageView.image = originalImage // Fallback if context creation fails
                }
            }
            
            // Add tap gesture to show full-screen image
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageViewTapped))
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(tapGesture)
        } else {
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .systemGray3
        }
        
        // Configure labels
        chineseLabel.text = taggedObject.chinese
        pinyinLabel.text = taggedObject.pinyin
        englishLabel.text = taggedObject.english
        
        // Configure review info
        setupReviewInfo()
    }
    
    @objc private func imageViewTapped() {
        guard let image = imageView.image else { return }
        
        // Create container view for full-screen display
        let containerView = UIView(frame: view.window?.bounds ?? view.bounds)
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        containerView.alpha = 0
        
        // Create image view to display the full-size image
        let fullImageView = UIImageView(frame: containerView.bounds)
        fullImageView.contentMode = .scaleAspectFit
        fullImageView.image = image
        // No need to apply rotation as the image is already rotated
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views to container
        containerView.addSubview(fullImageView)
        containerView.addSubview(closeButton)
        
        // Add constraints for close button
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add tap gesture to close
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFullScreenImage))
        closeButton.addGestureRecognizer(tapGesture)
        containerView.tag = 1001  // Tag for identification
        
        // Add to view hierarchy
        if let window = view.window {
            window.addSubview(containerView)
        } else {
            view.addSubview(containerView)
        }
        
        // Animate appearance
        UIView.animate(withDuration: 0.3) {
            containerView.alpha = 1.0
        }
    }
    
    @objc private func dismissFullScreenImage(_ gesture: UITapGestureRecognizer) {
        guard let containerView = gesture.view?.superview,
              containerView.tag == 1001 else { return }
        
        // Animate dismissal
        UIView.animate(withDuration: 0.3, animations: {
            containerView.alpha = 0
        }) { _ in
            containerView.removeFromSuperview()
        }
    }
    
    private func setupReviewInfo() {
        // Clear existing review info
        reviewInfoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add review information
        let reviewCount = createInfoRow(title: "Review Count", value: "\(taggedObject.reviewCount)")
        let successRate = createInfoRow(title: "Success Rate", value: calculateSuccessRate())
        let lastReviewed = createInfoRow(title: "Last Reviewed", value: formatDate(taggedObject.lastReviewDate))
        let nextReview = createInfoRow(title: "Next Review", value: formatDate(taggedObject.nextReviewDate))
        let dateAdded = createInfoRow(title: "Added", value: formatDate(taggedObject.timestamp))
        
        reviewInfoStack.addArrangedSubview(reviewCount)
        reviewInfoStack.addArrangedSubview(successRate)
        reviewInfoStack.addArrangedSubview(lastReviewed)
        reviewInfoStack.addArrangedSubview(nextReview)
        reviewInfoStack.addArrangedSubview(dateAdded)
    }
    
    private func createInfoRow(title: String, value: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16, weight: .medium)
        valueLabel.textColor = .label
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    private func calculateSuccessRate() -> String {
        if taggedObject.reviewCount == 0 {
            return "N/A"
        }
        let rate = Double(taggedObject.successCount) / Double(taggedObject.reviewCount) * 100
        return String(format: "%.1f%%", rate)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    @objc private func pronounceTapped() {
        guard let chinese = taggedObject.chinese else { return }
        
        let utterance = AVSpeechUtterance(string: chinese)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        
        speechSynthesizer.speak(utterance)
        
        // Provide visual feedback
        UIView.animate(withDuration: 0.2, animations: {
            self.pronunciationButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.pronunciationButton.transform = .identity
            }
        }
    }
    
    @objc private func editTapped() {
        // Create alert controller
        let alert = UIAlertController(title: "Edit Object", message: nil, preferredStyle: .actionSheet)
        
        // Add review action
        alert.addAction(UIAlertAction(title: "Review Now", style: .default) { [weak self] _ in
            self?.reviewObject()
        })
        
        // Add delete action
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteObject()
        })
        
        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func reviewObject() {
        // Create alert for review quality
        let alert = UIAlertController(title: "How well did you remember?", message: nil, preferredStyle: .actionSheet)
        
        let qualities = [
            (5, "Perfect Response", "Immediate perfect recall"),
            (4, "Good Response", "Correct after a brief hesitation"),
            (3, "Moderate Response", "Correct with some difficulty"),
            (2, "Poor Response", "Wrong initially but remembered"),
            (1, "Incorrect", "Wrong answer but recognized correct one"),
            (0, "Complete Blackout", "Total failure to recall")
        ]
        
        for (quality, title, description) in qualities {
            alert.addAction(UIAlertAction(title: "\(title) - \(description)", style: .default) { [weak self] _ in
                self?.updateReviewStatus(quality: quality)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateReviewStatus(quality: Int) {
        PersistenceController.shared.updateReviewStatus(for: taggedObject, wasCorrect: quality != 0, context: context)
        setupReviewInfo() // Refresh the review info display
    }
    
    private func deleteObject() {
        let alert = UIAlertController(
            title: "Delete Object",
            message: "Are you sure you want to delete this object? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            self.context.delete(self.taggedObject)
            
            do {
                try self.context.save()
                self.navigationController?.popViewController(animated: true)
            } catch {
                print("Error deleting object: \(error)")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
} 