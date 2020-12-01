//
//  UserController.swift
//  FinalProject
//
//  Created by Clarissa Vinciguerra on 11/19/20.
//

import Foundation
import Firebase

class UserController {
    
    // MARK: - Properties
    static let shared = UserController()
    let database = Firestore.firestore()
    var currentUser: User?
    var matchedUser: User? // this was used for location func - probably better to have as a local property in the VC
    let userCollection = "users"
    var randos: [User] = []
    var sentRequests: [User] = []
    var pendingRequests: [User] = []
    var friends: [User] = []
    
    // MARK: - CREATE

    func createUser(name: String, bio: String, type: String, dateOfBirth: Date, latitude: Double, longitude: Double, images: [UIImage], uuid: String, completion: @escaping (Result<User, UserError>) -> Void) {

        let newUser = User(name: name, dateOfBirth: dateOfBirth, bio: bio, type: type, latitude: latitude, longitude: longitude, uuid: uuid, images: images)
        
        let timeInterval = newUser.dateOfBirth.timeIntervalSince1970
        
        let dispatchGroup = DispatchGroup()
        var imageURLs: [String] = []

        for image in images {
            dispatchGroup.enter()
            let fileName = UUID().uuidString

            guard let imageData = image.jpegData(compressionQuality: 0.2) else { return completion(.failure(.errorConvertingImage))}
            StorageController.shared.uploadImage(with: imageData, fileName: fileName) { (result) in
                switch result {
                case .success(let urlString):
                    print("Image \(fileName) successfully uploaded!")
                    imageURLs.append(urlString)
                    dispatchGroup.leave()
                case .failure(let error):
                    print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let userReference = self.database.collection(self.userCollection)
            userReference.document("\(newUser.uuid)").setData([
                UserStrings.nameKey : "\(newUser.name)",
                UserStrings.bioKey : "\(bio)",
                UserStrings.typeKey : "\(type)",
                UserStrings.dateOfBirthKey : timeInterval,
                //UserStrings.imagesKey : dataArray,
                UserStrings.imageUUIDsKey : imageURLs,
                UserStrings.latitudeKey : newUser.latitude,
                UserStrings.longitudeKey : newUser.longitude,
                UserStrings.friendsKey : newUser.friends,
                UserStrings.pendingRequestsKey : newUser.pendingRequests,
                UserStrings.sentRequestsKey : newUser.sentRequests,
                UserStrings.blockedArrayKey : newUser.blockedArray
                
            ]) { error in
                if let error = error {
                    print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
                    return completion(.failure(.firebaseError(error)))
                } else {
                    print("Milestone document added with ID: \(newUser.uuid)")
                    newUser.imageUUIDs = imageURLs
                    self.currentUser = newUser
                    return completion(.success(newUser))
                }
            }
        }
    }

    
    
    // MARK: - READ
    func fetchUserByName(_ name: String, completion: @escaping (Result<User, UserError>) -> Void) {
        let userReference = database.collection(userCollection)
        
       userReference.whereField(UserStrings.nameKey, isEqualTo: name).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
                return completion(.failure(.firebaseError(error)))
            } else {
                if let doc = querySnapshot!.documents.first {
                    guard let fetchedUser = User(document: doc) else {
                        return completion(.failure(.couldNotUnwrap))
                    }
                    return completion(.success(fetchedUser))
                }
            }
        }
    }
    
    func fetchUserByUUID(_ uuid: String, completion: @escaping (Result<User, UserError>) -> Void) {
        let userDocRef = database.collection(userCollection).document(uuid)
        
        userDocRef.getDocument { (document, error) in
            
            if let document = document, document.exists {
                guard let user = User(document: document) else { return }
                completion(.success(user))
                
            } else if let error = error {
                
                completion(.failure(.firebaseError(error)))
                
            }
        }
        completion(.failure(.noExistingUser))
    }
    

    func checkThatUserExists(with uuid: String, completion: @escaping ((Bool) -> Void)) {
        let docRef = database.collection(userCollection).document(uuid)
        
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let dataDescription = document.data().map(String.init(describing:)) ?? "nil"
                print("Document data: \(dataDescription)")
                return completion(true)
            } else {
                print("Document does not exist")
                return completion(false)
            }
        }

    }
    
    func fetchFilteredRandos(currentUser: User, completion: @escaping (Result<[User], UserError>) -> Void) {
        let userDocRef = database.collection(userCollection)
        
        // add a line here to filter by city/location in the real app
        userDocRef.getDocuments { (querySnapshot, error) in
            if let error = error {
                
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
                return completion(.failure(.firebaseError(error)))
                
            } else {
                
                var randosToAppear: [User] = []
                var doNotAppearArray = currentUser.blockedArray
                doNotAppearArray.append(contentsOf: currentUser.sentRequests)
                doNotAppearArray.append(contentsOf: currentUser.friends)
                // change to uuid in final
                doNotAppearArray.append(currentUser.uuid)
                
                for document in querySnapshot!.documents {
                    // print("\(document.documentID) => \(document.data())")
                    if let rando = User(document: document) {
                        
                        for uuid in rando.blockedArray {
                            if currentUser.uuid == uuid {
                                doNotAppearArray.append(rando.uuid)
                            }
                        }
                        
                        var makeThisRandoAppear = true
                        
                        for uuid in doNotAppearArray {
                            if rando.uuid == uuid {
                                makeThisRandoAppear = false
                            }
                        }
                        
                        if makeThisRandoAppear {
                            randosToAppear.append(rando)
                        }
                    }
                }
                completion(.success(randosToAppear))
            }
        }
    }
    
    func fetchUsersFrom (_ currentUserArray: [String], completion: @escaping (Result<[User], UserError>) -> Void) {
        
        let dispatchGroup = DispatchGroup()
        var fetchedUsers: [User] = []
        
        for uuid in currentUserArray {
            
            dispatchGroup.enter()
            
            let docRef = database.collection(userCollection).document(uuid)
            docRef.getDocument { (document, error) in
                
                if let document = document, document.exists {
                    guard let user = User(document: document) else { return }
                    fetchedUsers.append(user)
                    dispatchGroup.leave()
                } else if let error = error {
                    completion(.failure(.firebaseError(error)))
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            return completion(.success(fetchedUsers))
        }
    }
    
    // MARK: - UPDATE
    // this update function will be used as we append to arrays locally and update remotely: send friend request and confirm friend request
    func updateUserBy(_ user: User, completion: @escaping (Result<User, UserError>) -> Void) {
        let documentReference = database.collection(userCollection).document(user.uuid)
        
        documentReference.updateData([
                                        UserStrings.nameKey : "\(user.name)",
                                        UserStrings.latitudeKey : user.latitude,
                                        UserStrings.longitudeKey : user.longitude,
                                        UserStrings.imageUUIDsKey : user.images,
                                        UserStrings.friendsKey : user.friends,
                                        UserStrings.pendingRequestsKey : user.pendingRequests,
                                        UserStrings.sentRequestsKey : user.sentRequests,
                                        UserStrings.blockedArrayKey : user.blockedArray        ]) { (error) in
            if let error = error {
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
                return completion(.failure(.firebaseError(error)))
            } else {
                return completion(.success(user))
            }
        }
    }
    
    // MARK: - REMOVE
   
    func removeFromSentRequestsOf (_ user: User, andOtherUser: User, completion: @escaping (Result<Bool, UserError>) -> Void) {
        let pendingRequestsDocRef = database.collection(userCollection).document(andOtherUser.uuid)
        let sentRequestsDocRef = database.collection(userCollection).document(user.uuid)
        
        database.runTransaction({ (transaction, errorPointer) -> Any? in
            let pendingRequestDocument: DocumentSnapshot
            let sentRequestDocument: DocumentSnapshot
            do {
                try pendingRequestDocument = transaction.getDocument(pendingRequestsDocRef)
                try sentRequestDocument = transaction.getDocument(sentRequestsDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard var pendingRequestsArray = pendingRequestDocument.data()?[UserStrings.pendingRequestsKey] as? [String], var sentRequestsArray = sentRequestDocument.data()?[UserStrings.sentRequestsKey] as? [String] else {
                print("There was an error fetching pending request arrays while deleting a connection")
                return nil
            }
            
            guard let pendingRequestIndex = pendingRequestsArray.firstIndex(of: user.uuid), let sentRequestIndex = sentRequestsArray.firstIndex(of: andOtherUser.uuid) else { return completion(.failure(.couldNotUnwrap)) }
           
                pendingRequestsArray.remove(at: pendingRequestIndex)
                sentRequestsArray.remove(at: sentRequestIndex)
            transaction.updateData([UserStrings.pendingRequestsKey : pendingRequestsArray], forDocument: pendingRequestsDocRef)
            transaction.updateData([UserStrings.sentRequestsKey: sentRequestsArray], forDocument: sentRequestsDocRef)
               
            return completion(.success(true))
        
        }) { (object, error) in
            if let error = error {
                print("There was an error deleting this pending connection: Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }

    func removeFriend (otherUserUUID: String, currentUserUUID: String, completion: @escaping (Result<Bool, UserError>) -> Void) {
        let currentUserDocRef = database.collection(userCollection).document(currentUserUUID)
        let otherUserDocRef = database.collection(userCollection).document(otherUserUUID)

        database.runTransaction({ (transaction, errorPointer) -> Any? in
            let currentUserDoc: DocumentSnapshot
            let otherUserDoc: DocumentSnapshot
            do {
                try currentUserDoc = transaction.getDocument(currentUserDocRef)
                try otherUserDoc = transaction.getDocument(otherUserDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard var currentUserFriends = currentUserDoc.data()?[UserStrings.friendsKey] as? [String], var otherUserFriendsArray = otherUserDoc.data()?[UserStrings.friendsKey] as? [String] else {
                print("There was an error fetching pending request arrays while deleting a connection")
                return nil
            }
            
            guard let currentUserFriendsIndex = currentUserFriends.firstIndex(of: otherUserUUID), let otherUserFriendsIndex = otherUserFriendsArray.firstIndex(of: currentUserUUID) else { return completion(.failure(.couldNotUnwrap)) }
           
                currentUserFriends.remove(at: currentUserFriendsIndex)
                otherUserFriendsArray.remove(at: otherUserFriendsIndex)
            
            transaction.updateData([UserStrings.friendsKey : currentUserFriends], forDocument: currentUserDocRef)
            transaction.updateData([UserStrings.friendsKey: otherUserFriendsArray], forDocument: otherUserDocRef)
               
            return completion(.success(true))
        
        }) { (object, error) in
            if let error = error {
                print("There was an error deleting this pending connection: Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
 
    
    // The following function may not be necessary in our app. In order to unblock a user, you'd need to be able to search for them! The whole idea is that you wouldn't show up in their search and they'd no longer show up in yours. Please bring it to my attention if there is an important gap in that logic
    func removeFromBlockedArrayOf (currentUser: User, blockedUserUUID: String, completion: @escaping (Result<User, UserError>) -> Void) {
        
        let unblockedDocRef = database.collection(userCollection).document(currentUser.uuid)

        database.runTransaction({ (transaction, errorPointer) -> Any? in
            let unblockDocument: DocumentSnapshot
    
            do {
                try unblockDocument = transaction.getDocument(unblockedDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard var blockedArray = unblockDocument.data()?["blocked"] as? [String] else {
                print("There was an error fetching the blocked array for the current user.")
                return nil
            }
            
            guard let blockedIndex = blockedArray.firstIndex(of: blockedUserUUID) else { return completion(.failure(.couldNotUnwrap)) }
           
                blockedArray.remove(at: blockedIndex)
                transaction.updateData(["blocked": blockedArray], forDocument: unblockedDocRef)
               
            return completion(.success(currentUser))
        
        }) { (object, error) in
            if let error = error {
                print("There was an error deleting this UUID from the current user's blocked array: Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
   
    // MARK: - DELETE
    func deleteUserInfoWith(_ uuid: String, completion: @escaping ((Bool) -> Void)) {
        database.collection(userCollection).document(uuid).delete() { err in
            if let err = err {
                print("Error removing document: \(err)")
                completion(false)
            } else {
                print("User successfully deleted.")
                completion(true)
            }
        }
    }
    
}
