//
//  StorageController.swift
//  FinalProject
//
//  Created by Clarissa Vinciguerra on 11/19/20.
//

import Foundation
import FirebaseStorage
import Firebase

final class StorageController {
    
    // MARK: - Properties
    static let shared = StorageController()
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    // MARK: - CRUD Functions
    /// Uploads picture to firebase storage and returns completion with url string to download.
    public func uploadImage(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            guard error == nil else {
                print("Failed to upload data to firebase for picture.")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            completion(.success(fileName))
//            self.storage.child("images/\(fileName)").downloadURL (completion: { url, error in
//                guard let url = url else {
//                    print("Failed to get download url")
//                    completion(.failure(StorageErrors.failedToGetDownloadURL))
//                    return
//                }
//
//                let urlString = url.absoluteString
//                print("download url returned: \(urlString)")
//                completion(.success(urlString))
//                return
//            })
        })
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL { (url, error) in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        }
    }
    
    public func deleteImage(at index: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        // keep data in sync everywhere there is data - AVOID THE BUGS EWWWW BUGGSSSS.
        
        // 1. currentUser.imageURLs - must be removed locally from this array CHECK!!!!!
        guard let imageUUID = UserController.shared.currentUser?.imageUUIDs.remove(at: index) else { return completion(.failure(StorageErrors.imageNotFound)) }
        
        // 2. The URL also exists in firestore (images array in firestore), see line 75
        removeImage(with: imageUUID) { (result) in
            switch result {
            case .success():
                // 3. the image in the storage itself
                self.storage.child("images/\(imageUUID)").delete { (error) in
                    if let error = error {
                        return completion(.failure(error))
                    }
                    completion(.success(()))
                }
            case .failure(let error):
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
        
    }
    
    private func removeImage(with uuid: String, completion: @escaping(Result<Void, UserError>) -> Void) {
        
        guard let currentUser = UserController.shared.currentUser else { return completion(.failure(.noExistingUser)) }
        
        let database = UserController.shared.database
        
        let docRef = database.collection(UserController.shared.userCollection).document(currentUser.uuid)
        
        database.runTransaction({ (transaction, errorPointer) -> Any? in
            let imageUUIDDocument: DocumentSnapshot
            
            do {
                try imageUUIDDocument = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var imageUUIDs = imageUUIDDocument.data()?["imageUUIDs"] as? [String] else {
                print("There was an error fetching the blocked array for the current user.")
                return nil
            }
            
            guard let imageUUIDIndex = imageUUIDs.firstIndex(of: uuid) else { return completion(.failure(.couldNotUnwrap)) }
            
            imageUUIDs.remove(at: imageUUIDIndex)
            transaction.updateData(["imageUUIDs": imageUUIDs], forDocument: docRef)
            
            return completion(.success(()))
            
        }) { (object, error) in
            if let error = error {
                print("There was an error deleting this UUID from the current user's blocked array: Error in \(#function) : \(error.localizedDescription) \n---\n \(error)")
            }
        }
    }
    
}
