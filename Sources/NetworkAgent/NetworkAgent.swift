//
//  NetworkAgent.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation
import Combine

public struct NetworkAgent {

    public struct Response<T> {
        /// The decoded payload wrapped in a `Result`.
        ///
        /// - `.success(T)` when the body decoded successfully.
        /// - `.failure(Error)` when the transport succeeded but decoding failed.
        ///
        /// Transport-level failures (no `HTTPURLResponse`) are surfaced as a thrown
        /// error from the request method itself and never reach this struct.
        public let data: Result<T, Error>
        public let response: HTTPURLResponse
    }

    func run<T: Decodable>(
        _ request: URLRequest,
        _ decoder: JSONDecoder = JSONDecoder(),
        from keyPath: String,
        dateFormat format: String,
        timeZone abbreviation: String,
        plugins: [NetworkAgentPlugin],
        from endpoint: NetworkAgentEndpoint
    ) -> AnyPublisher<Response<T>, Error> {
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { error -> Error in
                plugins.forEach { $0.onResponse(nil, with: nil, receiving: error, from: endpoint) }
                return error
            }
            .map { data, response -> Response<T> in
                let httpResponse = response as! HTTPURLResponse

                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone(abbreviation: abbreviation)
                formatter.dateFormat = format
                decoder.dateDecodingStrategy = .formatted(formatter)

                do {
                    let payload = try Self.extractPayload(from: data, keyPath: keyPath)
                    let decoded = try decoder.decode(T.self, from: payload)
                    plugins.forEach { $0.onResponse(httpResponse, with: payload, from: endpoint) }
                    return Response(data: .success(decoded), response: httpResponse)
                } catch {
                    plugins.forEach { $0.onResponse(httpResponse, with: data, receiving: error, from: endpoint) }
                    return Response(data: .failure(error), response: httpResponse)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    @available(macOS 12, *) @available(iOS 15, *)
    func run<T: Decodable>(
        _ request: URLRequest,
        _ decoder: JSONDecoder = JSONDecoder(),
        from keyPath: String,
        dateFormat format: String,
        timeZone abbreviation: String,
        plugins: [NetworkAgentPlugin],
        from endpoint: NetworkAgentEndpoint,
        for model: T.Type
    ) async throws -> Response<T> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            plugins.forEach { $0.onResponse(nil, with: nil, receiving: error, from: endpoint) }
            throw error
        }

        let httpResponse = response as! HTTPURLResponse

        do {
            let decoded = try decoder.decode(T.self, from: data)
            plugins.forEach { $0.onResponse(httpResponse, with: data, from: endpoint) }
            return Response(data: .success(decoded), response: httpResponse)
        } catch {
            plugins.forEach { $0.onResponse(httpResponse, with: data, receiving: error, from: endpoint) }
            return Response(data: .failure(error), response: httpResponse)
        }
    }

    private static func extractPayload(from data: Data, keyPath: String) throws -> Data {
        guard !keyPath.isEmpty else { return data }

        let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
        guard let dictionary = json as? [String: Any], let nested = dictionary[keyPath] else {
            return data
        }
        return try JSONSerialization.data(withJSONObject: nested, options: .prettyPrinted)
    }
}
