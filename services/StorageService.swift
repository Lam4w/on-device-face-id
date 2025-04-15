import Foundation
import UIKit

/// Protocol defining the storage operations for face data.
protocol StorageManaging {
    func saveEnrolledImage(_ image: UIImage) throws
    func loadEnrolledImage() -> UIImage?
    func deleteEnrolledImage() throws
    func getEnrolledImageURL() -> URL?
}

/// Manages the persistence of the enrolled face image to the device's local storage.
class StorageService: StorageManaging {

    private let fileManager = FileManager.default
    private let enrolledImageFilename = "enrolledFace.jpg"

    /// Returns the URL for the enrolled image file in the app's documents directory.
    /// - Returns: URL pointing to the potential location of the enrolled image, or nil if the directory cannot be found.
    func getEnrolledImageURL() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not access documents directory.")
            return nil
        }
        return documentsDirectory.appendingPathComponent(enrolledImageFilename)
    }

    /// Saves the provided image as the enrolled face image.
    /// Overwrites any existing enrolled image.
    /// - Parameter image: The UIImage to save.
    /// - Throws: An error if the image cannot be converted to JPEG data or if saving fails.
    func saveEnrolledImage(_ image: UIImage) throws {
        guard let imageURL = getEnrolledImageURL() else {
            throw StorageError.directoryNotFound
        }

        // Convert UIImage to JPEG data
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.encodingFailed
        }

        // Attempt to save the data
        do {
            try data.write(to: imageURL, options: [.atomic])
            print("Successfully saved enrolled image to: \(imageURL.path)")
        } catch {
            print("Error saving enrolled image: \(error)")
            throw StorageError.saveFailed(error)
        }
    }

    /// Loads the enrolled face image from local storage.
    /// - Returns: The loaded UIImage, or nil if no image is found or an error occurs during loading.
    func loadEnrolledImage() -> UIImage? {
        guard let imageURL = getEnrolledImageURL(),
              fileManager.fileExists(atPath: imageURL.path) else {
            return nil // No enrolled image exists
        }

        do {
            let data = try Data(contentsOf: imageURL)
            print("Successfully loaded enrolled image.")
            return UIImage(data: data)
        } catch {
            print("Error loading enrolled image: \(error)")
            return nil
        }
    }

    /// Deletes the currently enrolled face image from local storage.
    /// - Throws: An error if the file deletion fails.
    func deleteEnrolledImage() throws {
         guard let imageURL = getEnrolledImageURL(),
               fileManager.fileExists(atPath: imageURL.path) else {
             print("No enrolled image file to delete.")
             return // Nothing to delete
         }

         do {
             try fileManager.removeItem(at: imageURL)
             print("Successfully deleted enrolled image.")
         } catch {
             print("Error deleting enrolled image: \(error)")
             throw StorageError.deleteFailed(error)
         }
     }

    /// Custom errors related to storage operations.
    enum StorageError: Error, LocalizedError {
        case directoryNotFound
        case encodingFailed
        case saveFailed(Error)
        case deleteFailed(Error)

        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "Could not find the application's documents directory."
            case .encodingFailed:
                return "Failed to encode the image to JPEG data."
            case .saveFailed(let underlyingError):
                return "Failed to save the image: \(underlyingError.localizedDescription)"
            case .deleteFailed(let underlyingError):
                return "Failed to delete the image: \(underlyingError.localizedDescription)"
            }
        }
    }
}