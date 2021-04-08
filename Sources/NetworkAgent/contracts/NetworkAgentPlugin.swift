//
//  NetworkAgentPlugin.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public protocol NetworkAgentPlugin {
    func onRequest(_ request: URLRequest, with configuration: RequestConfiguration)
    func onResponse(_ response: HTTPURLResponse, with payload: Data)
    func onResponse(_ response: HTTPURLResponse?, with payload: Data?, receiving error: NetworkAgent.NetworkError, from endpoint: NetworkAgentEndpoint)
}

public extension NetworkAgentPlugin {
    func onRequest(_ request: URLRequest, with configuration: RequestConfiguration) {}
    func onResponse(_ response: HTTPURLResponse, with payload: Data) {}
    func onResponse(_ response: HTTPURLResponse? = nil, with payload: Data? = nil, receiving error: NetworkAgent.NetworkError, from endpoint: NetworkAgentEndpoint) {}
}
