//
//  Pagination.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation

class Pagination<T: Codable>: Codable {
    var count: Int
    var next: String?
    var previous: String?
    var results: [T] = []
}
