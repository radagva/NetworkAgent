//
//  NetworkAgentPlugin.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public protocol NetworkAgentPlugin: Sendable {
    /// Inspect or mutate the outgoing `URLRequest` before it is sent.
    /// Return the (possibly modified) request to forward down the chain.
    func onRequest(_ request: URLRequest) async throws -> URLRequest

    /// Inspect or mutate the response after the network call completes.
    /// `request` is the final request that was actually sent (after running
    /// through every `onRequest` interceptor).
    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest
    ) async throws -> (data: Data, response: URLResponse)
}

public extension NetworkAgentPlugin {
    func onRequest(_ request: URLRequest) async throws -> URLRequest { request }

    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest
    ) async throws -> (data: Data, response: URLResponse) {
        (data: data, response: response)
    }
}
