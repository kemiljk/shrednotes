//
//  AIModelAvailability.swift
//  Shrednotes
//
//  Created by Karl Koch on 23/06/2025.
//

import Foundation
import FoundationModels

@available(iOS 26, *)
enum AIModelError: Error, LocalizedError {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable(Error?)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotEligible:
            return "AI features are not available on this device."
        case .appleIntelligenceNotEnabled:
            return "Please enable Apple Intelligence in Settings to use this feature."
        case .modelNotReady:
            return "AI model is still loading. Please try again in a moment."
        case .unavailable(let underlyingError):
            if let error = underlyingError {
                return "AI features are currently unavailable: \(error.localizedDescription)"
            } else {
                return "AI features are currently unavailable."
            }
        }
    }
}

@available(iOS 26, *)
struct AIModelAvailability {
    static func checkAvailability() -> Result<SystemLanguageModel, AIModelError> {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            return .success(model)
            
        case .unavailable(.deviceNotEligible):
            return .failure(.deviceNotEligible)
            
        case .unavailable(.appleIntelligenceNotEnabled):
            return .failure(.appleIntelligenceNotEnabled)
            
        case .unavailable(.modelNotReady):
            return .failure(.modelNotReady)
            
        case .unavailable(let underlyingError):
            return .failure(.unavailable(underlyingError as? Error))
        }
    }
    
    static func withAvailability<T>(
        perform action: @escaping () async throws -> T,
        onUnavailable: @escaping (AIModelError) async -> Void
    ) async -> T? {
        switch checkAvailability() {
        case .success:
            do {
                return try await action()
            } catch {
                if let modelError = error as? AIModelError {
                    await onUnavailable(modelError)
                } else {
                    await onUnavailable(.unavailable(error))
                }
                return nil
            }
            
        case .failure(let error):
            await onUnavailable(error)
            return nil
        }
    }
}
