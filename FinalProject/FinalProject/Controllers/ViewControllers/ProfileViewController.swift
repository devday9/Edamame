//
//  ProfileViewController.swift
//  FinalProject
//
//  Created by Clarissa Vinciguerra on 11/19/20.
//

import UIKit
import CoreLocation

class ProfileViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var nameAndAgeLabel: UILabel!
    @IBOutlet weak var typeOfVeganLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var addAcceptRevokeButton: UIButton!
    @IBOutlet weak var declineButton: UIButton!
    @IBOutlet weak var blockButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Properties
    var viewsLaidOut = false
    var otherUser: User?
    
    // MARK: - Lifecyle Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if viewsLaidOut == false {
            setupViews()
            viewsLaidOut = true
        }
    }
    
    func setupViews() {
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = configureCollectionViewLayout()
        collectionView.backgroundColor = .whiteSmoke
        
        nameAndAgeLabel.textColor = .softBlack
        distanceLabel.textColor = .softBlack
        typeOfVeganLabel.textColor = .softBlack
        bioLabel.textColor = .softBlack
        
        addAcceptRevokeButton.backgroundColor = .edamameGreen
        addAcceptRevokeButton.tintColor = .whiteSmoke
        addAcceptRevokeButton.addCornerRadius()
        addAcceptRevokeButton.addAccentBorder()
        
        declineButton.backgroundColor = .edamameGreen
        declineButton.tintColor = .whiteSmoke
        declineButton.addCornerRadius()
        declineButton.addAccentBorder()
        
        blockButton.backgroundColor = .whiteSmoke
        blockButton.tintColor = .darkerGreen
        blockButton.addCornerRadius()
        blockButton.addAccentBorder()
    }
    
    func configureCollectionViewLayout() -> UICollectionViewLayout {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        
        let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.95), heightDimension: .fractionalHeight(1))
        
        let layoutGroup = NSCollectionLayoutGroup.horizontal(layoutSize: layoutGroupSize, subitems: [layoutItem])
        
        let layoutSection = NSCollectionLayoutSection(group: layoutGroup)
        layoutSection.orthogonalScrollingBehavior = .groupPaging
        layoutSection.contentInsets = .init(top: 5, leading: 5, bottom: 5, trailing: 5)
        layoutSection.interGroupSpacing = 5
        
        return UICollectionViewCompositionalLayout(section: layoutSection)
    }
    
    // MARK: - Actions
    @IBAction func addAcceptRevokeButtonTapped(_ sender: Any) {
        updateFriendStatus()
    }
    
    @IBAction func declineButtonTapped(_ sender: Any) {
        declineFriendRequest()
    }
    
    @IBAction func blockButtonTapped(_ sender: Any) {
        blockUser()
    }
    
    @IBAction func reportButtonTapped(_ sender: Any) {
        reportUser()
    }
    
    // MARK: - Class Methods
    func updateFriendStatus() {
        guard let otherUser = otherUser, let currentUser = UserController.shared.currentUser else { return }
        
        if currentUser.pendingRequests.contains(otherUser.uuid) {
            // remove pending status and place in friends array
            removeSentRequestOf(otherUser, andPendingRequestOf: currentUser)
            
            currentUser.friends.append(otherUser.uuid)
            otherUser.friends.append(currentUser.uuid)
            
            update(currentUser)
            updateOtherUser(with: otherUser)
            
        } else if let index = currentUser.friends.firstIndex(of: otherUser.uuid) {
            // remove from friends arrays and put other user in blocked array
            currentUser.friends.remove(at: index)
            
            removeFriend(from: otherUser, and: currentUser)
            
        } else {
            // Initiate a first request and appends users to respective arrays
            currentUser.sentRequests.append(otherUser.uuid)
            otherUser.pendingRequests.append(currentUser.uuid)
            
            update(otherUser)
            update(currentUser)
            updateViews()
        }
    }
    
    private func update(_ user: User) {
        UserController.shared.updateUserBy(user) { (result) in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    UserController.shared.currentUser = user
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
    private func updateOtherUser(with otherUser: User) {
        UserController.shared.updateUserBy(otherUser) { (result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    print("User Updated Successfully")
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
    private func removeSentRequestOf(_ otherUser: User, andPendingRequestOf user: User) {
        
        UserController.shared.removeFromSentRequestsOf(otherUser, andPendingRequestOf: user) { (result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    self.updateViews()
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
    private func removeFriend(from otherUser: User, and currentUser: User) {
        UserController.shared.removeFriend(otherUserUUID: otherUser.uuid, currentUserUUID: currentUser.uuid) { (result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    // present alert to user that friend has been removed
                    // delete messages
                    // send back to randoVC
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
    func declineFriendRequest() {
        guard let otherUser = otherUser, let currentUser = UserController.shared.currentUser else { return }
        
        if let index = currentUser.pendingRequests.firstIndex(of: otherUser.uuid) {
            removeSentRequestOf(otherUser, andPendingRequestOf: currentUser)
        }
        
        blockUser()
        
        // add alert that says "user blocked!" here
        
        navigationController?.popViewController(animated: true)
    }
    
    func blockUser() {
        guard let otherUser = otherUser, let currentUser = UserController.shared.currentUser else { return }
        
        if currentUser.friends.contains(otherUser.uuid) {
            removeFriend(from: currentUser, and: otherUser)
        }
        
        currentUser.blockedArray.append(otherUser.uuid)
        UserController.shared.updateUserBy(currentUser) { (result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    print("OtherUser UUID has been successfully appended to currentUsers blocked array.")
                    // send back to RandoVC
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
    func reportUser() {
        guard let otherUser = otherUser else { return }
        
        otherUser.reportCount += 1
        
        if otherUser.reportCount >= 3 {
            otherUser.reportedThrice = true
        }
        update(otherUser)
        blockUser()
    }
    
    // MARK: - UpdateViews
    func updateViews() {
        guard let otherUser = otherUser, let currentUser = UserController.shared.currentUser, let age = otherUser.dateOfBirth.calcAge() else { return }
        
        let currentUserLocation = CLLocation(latitude: currentUser.latitude, longitude: currentUser.longitude)
        let otherUserLocation = CLLocation(latitude: otherUser.latitude, longitude: otherUser.longitude)
        
        distanceLabel.text = "\(round(currentUserLocation.distance(from: otherUserLocation) * 0.000621371)) mi"
        nameAndAgeLabel.text = otherUser.name + " " + age
        bioLabel.text = otherUser.bio
        typeOfVeganLabel.text = otherUser.type
        
        declineButton.alpha = 0
        addAcceptRevokeButton.alpha = 1
        blockButton.setTitle("Block", for: .normal)
        
        if currentUser.sentRequests.contains(otherUser.uuid) {
            
            addAcceptRevokeButton.setTitle("Request Sent", for: .normal)
            addAcceptRevokeButton.isEnabled = false
            
        } else if currentUser.pendingRequests.contains(otherUser.uuid) {
            
            addAcceptRevokeButton.setTitle("Accept", for: .normal)
            declineButton.alpha = 1
            declineButton.setTitle("Decline", for: .normal)
            
        } else if currentUser.friends.contains(otherUser.uuid) {
            
            addAcceptRevokeButton.isEnabled = false
            addAcceptRevokeButton.setTitle("Friends!", for: .disabled)
            
        } else {
            
            addAcceptRevokeButton.setTitle("Request Friend", for: .normal)
            
        }
    }
}

//MARK: - Extensions
extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return otherUser?.images.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "profileViewCell", for: indexPath) as? ViewPhotoCollectionViewCell else { return UICollectionViewCell() }
        
        cell.photo = otherUser?.images[indexPath.row]
        
        return cell
    }
}
