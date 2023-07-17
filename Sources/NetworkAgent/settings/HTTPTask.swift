//
//  HTTPTask.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public enum HTTPTask {
    case plain
    case attributes(attributes: [String: Any], encoding: HTTPURLEncoding)
    case raw(content: Any)
    case upload(parts: [HTTPMultipartTask])
}
