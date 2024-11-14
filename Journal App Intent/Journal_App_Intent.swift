//
//  Journal_App_Intent.swift
//  Journal App Intent
//
//  Created by Karl Koch on 14/11/2024.
//

import AppIntents

struct Journal_App_Intent: AppIntent {
    static var title: LocalizedStringResource { "Journal App Intent" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
