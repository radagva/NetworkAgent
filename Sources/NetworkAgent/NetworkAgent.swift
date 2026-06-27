//
//  NetworkAgent.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation
import Combine

public struct NetworkAgent {

    func run(
        _ request: URLRequest,
        plugins: [NetworkAgentPlugin],
        from endpoint: NetworkAgentEndpoint
    ) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { error -> Error in
                plugins.forEach { $0.onResponse(nil, with: nil, receiving: error, from: endpoint) }
                return error
            }
            .map { data, response -> (data: Data, response: URLResponse) in
                if let httpResponse = response as? HTTPURLResponse {
                    plugins.forEach { $0.onResponse(httpResponse, with: data, from: endpoint) }
                }
                return (data: data, response: response)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    @available(macOS 12, *) @available(iOS 15, *)
    func run(
        _ request: URLRequest,
        plugins: [NetworkAgentPlugin],
        from endpoint: NetworkAgentEndpoint
    ) async throws -> (data: Data, response: URLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            plugins.forEach { $0.onResponse(nil, with: nil, receiving: error, from: endpoint) }
            throw error
        }

        if let httpResponse = response as? HTTPURLResponse {
            plugins.forEach { $0.onResponse(httpResponse, with: data, from: endpoint) }
        }
        return (data: data, response: response)
    }
}
