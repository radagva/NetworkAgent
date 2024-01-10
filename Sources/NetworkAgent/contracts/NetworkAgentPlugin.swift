//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation

public protocol NetworkAgentPlugin {
    func onRequest(_ request: inout URLRequest)
    func onResponse(_ response: HTTPURLResponse, receiving data: Data, from request: URLRequest)
    func onResponseError(_ error: HTTPError, having response: HTTPURLResponse, from request: URLRequest)
}

public extension NetworkAgentPlugin {
    func onRequest(_ request: inout URLRequest) {}
    func onResponse(_ response: HTTPURLResponse, from request: URLRequest) {}
    func onResponseError(_ error: HTTPError, having response: HTTPURLResponse, from request: URLRequest) {}
}
