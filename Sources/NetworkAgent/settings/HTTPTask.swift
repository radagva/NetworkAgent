//
//  HTTPTask.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public enum HTTPTask {
    case requestPlain
    case requestAttributes(attributes: [String: Any], encoding: HTTPURLEncoding)
    case requestWithoutAttributes(content: Any)
    case upload(parts: [HTTPMultipartTask])
}
