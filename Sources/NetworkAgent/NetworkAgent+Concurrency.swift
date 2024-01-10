//
//  File.swift
//  
//
//  Created by Angel Rada on 8/1/24.
//

import Foundation
extension NetworkAgent {
    @available(macOS 12, *) @available(iOS 15, *)
    func run<T: Decodable>(
        _ request: URLRequest,
        _ decoder: JSONDecoder = JSONDecoder(),
        from keyPath: String,
        dateFormat format: String,
        timeZone abbreviation: String,
        from endpoint: NetworkAgentEndpoint,
        for model: T.Type,
        plugins: [NetworkAgentPlugin] = []
    ) async throws -> Response<T> {
        let (data, result) = try await URLSession.shared.data(for: request)
        
        let response = result as! HTTPURLResponse
        
        return try prepareResponse(request: request, response: response, data: data, keyPath: keyPath, decoder: decoder, plugins: plugins)
    }
}
