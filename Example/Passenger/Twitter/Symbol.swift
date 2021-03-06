//
//  Symbol.swift
//  Passenger
//
//  Created by Kellan Cummings on 7/11/15.
//  Copyright (c) 2015 CocoaPods. All rights reserved.
//

import Foundation
import Passenger

class Symbol: Entity {
    var text: String?
    var indices = [Int]()

    var entity = BelongsTo<StatusEntity>()
}