//
//  NetworkAgentPlugin.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public protocol NetworkAgentPlugin: Sendable {
    /// Inspect or mutate the outgoing `URLRequest` before it is sent. The
    /// `endpoint` is provided so interceptors can branch on which call is
    /// being made. Return the (possibly modified) request to forward down the
    /// chain.
    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest

    /// Inspect or mutate the response after the network call completes.
    ///
    /// - parameter request: the final request that was actually sent (after
    ///   every prior `onRequest` interceptor ran).
    /// - parameter endpoint: the endpoint that produced this request.
    /// - parameter agent: a `NetworkAgent` for firing side-requests (e.g.
    ///   refreshing a token, retrying the original call). Requests fired
    ///   through `agent.request(_:)` do NOT run through the plugin chain.
    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse)
}

public extension NetworkAgentPlugin {
    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest {
        request
    }

    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse) {
        (data: data, response: response)
    }
}
