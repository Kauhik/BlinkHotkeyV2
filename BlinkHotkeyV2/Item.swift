//
//  Item.swift
//  BlinkHotkeyV2
//
//  Created by Kaushik Manian on 30/3/25.
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
