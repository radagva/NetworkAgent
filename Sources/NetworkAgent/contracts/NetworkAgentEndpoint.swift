//
//  NetowrkAgentEndpoint.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public protocol NetworkAgentEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var task: HTTPTask { get }
}

extension NetworkAgentEndpoint {
    func process() {}
    
    var headers: [String: String] {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}
