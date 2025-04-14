import Foundation
import SwiftUI

/// Service responsible for storing and retrieving face feature prints
class StorageService: ObservableObject {
    private let storageKey = "stored_faces"
    @Published var storedFaces: [StoredFace] = []
    
    init() {
        loadStoredFaces()
    }
    
    /// Loads stored faces from UserDefaults
    private func loadStoredFaces() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                storedFaces = try JSONDecoder().decode([StoredFace].self, from: data)
            } catch {
                print("Error loading stored faces: \(error)")
                storedFaces = []
            }
        }
    }
    
    /// Saves the current stored faces to UserDefaults
    private func saveStoredFaces() {
        do {
            let data = try JSONEncoder().encode(storedFaces)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Error saving stored faces: \(error)")
        }
    }
    
    /// Adds a new face to storage
    /// - Parameters:
    ///   - name: Name to associate with the face
    ///   - featurePrintData: Face feature print data
    /// - Returns: The stored face object
    func storeFace(name: String, featurePrintData: Data) -> StoredFace {
        let storedFace = StoredFace(name: name, featurePrintData: featurePrintData)
        storedFaces.append(storedFace)
        saveStoredFaces()
        return storedFace
    }
    
    /// Updates an existing face in storage
    /// - Parameter face: The face to update
    func updateFace(_ face: StoredFace) {
        if let index = storedFaces.firstIndex(where: { $0.id == face.id }) {
            storedFaces[index] = face
            saveStoredFaces()
        }
    }
    
    /// Removes a face from storage
    /// - Parameter id: ID of the face to remove
    func removeFace(id: UUID) {
        storedFaces.removeAll { $0.id == id }
        saveStoredFaces()
    }
    
    /// Removes all stored faces
    func clearAllFaces() {
        storedFaces.removeAll()
        saveStoredFaces()
    }
}