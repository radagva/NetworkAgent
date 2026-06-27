//
//  NetworkAgentProvider.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public struct NetworkAgentProvider<E: NetworkAgentEndpoint>: Sendable {

    private let agent: NetworkAgent = .init()
    private let plugins: [NetworkAgentPlugin]

    public init(plugins: [NetworkAgentPlugin] = []) {
        self.plugins = plugins
    }

    public func request(endpoint: E) async throws -> (data: Data, response: URLResponse) {
        let request = NetworkAgent.configure(endpoint: endpoint)
        return try await agent.run(request, endpoint: endpoint, plugins: plugins)
    }
}
