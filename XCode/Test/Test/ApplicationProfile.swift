//
//  ApplicationProfile.swift
//  Test
//
//  Created by Heidy Hernandez on 12/3/24.
//

import ManagedSettings

struct ApplicationProfile: Codable, Hashable {
    let id: UUID
    let applicationToken: ApplicationToken
    
    init(id: UUID = UUID(), applicationToken: ApplicationToken) {
        self.applicationToken = applicationToken
        self.id = id
    }
}**
