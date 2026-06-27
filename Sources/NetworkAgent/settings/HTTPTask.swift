//
//  HTTPTask.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public enum HTTPTask: Sendable {
    case requestPlain
    case requestAttributes(attributes: [String: any Sendable], encoding: HTTPURLEncoding)
    case requestWithoutAttributes(content: any Sendable)
    case upload(parts: [HTTPMultipartTask])
}
