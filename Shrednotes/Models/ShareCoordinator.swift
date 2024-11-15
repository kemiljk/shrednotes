//
//  ShareCoordinator.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/11/2024.
//

import Combine

class ShareCoordinator: ObservableObject {
    @Published var shouldDismiss: Bool = false
    @Published var shouldSave: Bool = false

    func dismiss() {
        print("Dismiss called")
        shouldDismiss = true
    }

    func save() {
        print("Save called")
        shouldSave = true
    }
}
