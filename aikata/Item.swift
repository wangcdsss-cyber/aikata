//
//  Item.swift
//  aikata
//
//  Created by SHIHOU on 2026/05/06.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
