//
//  File.swift
//  
//
//  Created by Angel Rada on 8/1/24.
//

import Foundation

@available(macOS 12, *) @available(iOS 15, *)
extension NetworkAgentProvider {
    // MARK: Concurrent handler to perform requests
    public func request<T: Decodable>(endpoint: E, config: RequestConfiguration? = nil) async throws -> T {
        let (request, configuration) = configure(endpoint: endpoint, config: config)

        return try await run(request, config: configuration, from: endpoint)
    }
    
    /// ENDPOINT EXECUTER, THE GENERIC PARSES THE ENDPOINT RESPONSE TO THE REQUIRED DATA Codable MODEL
    private func run<T: Decodable>(
        _ request: URLRequest,
        config: RequestConfiguration,
        from endpoint: NetworkAgentEndpoint
    ) async throws -> T {
        do {
            let result = try await agent.run(
                request,
                config.decoder,
                from: config.from,
                dateFormat: config.dateFormat,
                timeZone: config.timeZone,
                from: endpoint,
                for: T.self,
                plugins: plugins
            )
            
            return result.value
        } catch {
            throw error
        }
    }
}
