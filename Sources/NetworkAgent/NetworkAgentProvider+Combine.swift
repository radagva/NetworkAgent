//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation
import Combine

extension NetworkAgentProvider {
    
    // MARK: Combine handler to perform requests
    public func request<T: Decodable>(endpoint: E, config: RequestConfiguration? = nil) -> AnyPublisher<T, Error> {
        let (request, configuration) = configure(endpoint: endpoint, config: config)
        
        return run(request, config: configuration, from: endpoint)
    }
    
    /// ENDPOINT EXECUTER, THE GENERIC PARSES THE ENDPOINT RESPONSE TO THE REQUIRED DATA Codable MODEL
    internal func run<T: Decodable>(
        _ request: URLRequest,
        config: RequestConfiguration,
        from endpoint: NetworkAgentEndpoint
    ) -> AnyPublisher<T, Error> {
        
        return agent.run(
            request,
            config.decoder,
            from: config.from,
            dateFormat: config.dateFormat,
            timeZone: config.timeZone,
            from: endpoint,
            plugins: plugins
        )
        .map(\.value)
        .eraseToAnyPublisher()
    }
}
