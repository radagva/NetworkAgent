//
//  NetworkAgent.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public struct NetworkAgent: Sendable {
    func run(
        _ request: URLRequest,
        plugins: [NetworkAgentPlugin],
    ) async throws -> (data: Data, response: URLResponse) {
        var finalRequest = request
        for plugin in plugins {
            finalRequest = try await plugin.onRequest(finalRequest)
        }

        let (data, response) = try await URLSession.shared.data(for: finalRequest)

        var finalData = data
        var finalResponse = response
        for plugin in plugins {
            let result = try await plugin.onResponse(
                finalResponse,
                data: finalData,
                request: finalRequest
            )
            finalData = result.data
            finalResponse = result.response
        }

        return (data: finalData, response: finalResponse)
    }
}
