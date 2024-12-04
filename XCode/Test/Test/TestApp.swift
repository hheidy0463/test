//
//  TestApp.swift
//  Test
//
//  Created by Heidy Hernandez on 12/3/24.
//

import SwiftUI
import FamilyControls

@main
struct ScreenTimeApp: App {
    
    let center = AuthorizationCenter.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        try await center.requestAuthorization(for: .individual)
                    } catch {
                        print("Failed to get authorization: \(error)")
                    }
                }
        }
    }
}
