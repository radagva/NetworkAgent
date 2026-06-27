//
//  NetworkAgent.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public struct NetworkAgent: Sendable {

    public init() {}

    /// Fires a one-off request for the given endpoint.
    ///
    /// This entry point is intended for use from inside a plugin's `onResponse`
    /// interceptor (e.g. refreshing an auth token, retrying the original call).
    /// Requests made through this method do NOT run through the plugin chain,
    /// which keeps interceptors from recursing into themselves.
    public func request(_ endpoint: any NetworkAgentEndpoint) async throws -> (data: Data, response: URLResponse) {
        let request = Self.configure(endpoint: endpoint)
        return try await URLSession.shared.data(for: request)
    }

    /// Internal entry point used by `NetworkAgentProvider` — runs the request
    /// through every registered plugin's `onRequest`/`onResponse` interceptor.
    func run(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        plugins: [NetworkAgentPlugin]
    ) async throws -> (data: Data, response: URLResponse) {
        var finalRequest = request
        for plugin in plugins {
            finalRequest = try await plugin.onRequest(finalRequest, endpoint: endpoint)
        }

        let (data, response) = try await URLSession.shared.data(for: finalRequest)

        var finalData = data
        var finalResponse = response
        for plugin in plugins {
            let result = try await plugin.onResponse(
                finalResponse,
                data: finalData,
                request: finalRequest,
                endpoint: endpoint,
                agent: self
            )
            finalData = result.data
            finalResponse = result.response
        }

        return (data: finalData, response: finalResponse)
    }

    // MARK: - URLRequest building

    static func configure(endpoint: any NetworkAgentEndpoint) -> URLRequest {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent(endpoint.path))

        endpoint.headers.forEach({
            var value = $0.value
            if case .upload = endpoint.task {
                value = "\($0.value); boundary=\(boundary)"
            }
            request.addValue(value, forHTTPHeaderField: $0.key)
        })

        request.httpMethod = endpoint.method.rawValue.uppercased()

        if case let .requestAttributes(attributes, encoding) = endpoint.task {
            switch encoding {
            case .json:
                request.httpBody = try? JSONSerialization.data(withJSONObject: attributes, options: .prettyPrinted)
            case .url:
                var components = URLComponents(string: request.url?.absoluteString ?? endpoint.baseURL.absoluteString)!
                components.queryItems = attributes.keys.map { URLQueryItem(name: $0, value: stringify(attributes[$0])) }
                components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                request.url = components.url!
            }
        }

        if case let .upload(parts) = endpoint.task {
            let body = NSMutableData()
            parts.forEach {
                if let myme = $0.mymetype {
                    body.append(makeUploadBoundaryData(field: $0.name, file: "\($0.filename)", myme: myme, fileData: $0.data, using: boundary))
                } else {
                    body.append(string: makeUploadBoundaryField(name: $0.name, value: $0.data, using: boundary))
                }
            }
            request.httpBody = body as Data
        }

        return request
    }

    private static func stringify(_ item: Any?) -> String {
        guard let item = item else { return "" }
        return "\(item)"
    }

    private static func makeUploadBoundaryField(name: String, value: Data, using boundary: String) -> String {
        var field = "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        field += "\r\n"
        field += "\(String(data: value, encoding: .utf8) ?? "")\r\n"
        return field
    }

    private static func makeUploadBoundaryData(field: String, file name: String, myme: String, fileData: Data, using boundary: String) -> Data {
        var data = Data()
        let CRLF = "\r\n"
        data.append("--\(boundary)\(CRLF)")
        data.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(name)\"\(CRLF)")
        data.append("Content-Type: \(myme)\(CRLF)\(CRLF)")
        data.append(fileData)
        data.append("\(CRLF)")
        data.append("--\(boundary)--\(CRLF)")
        return data
    }
}

fileprivate extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

fileprivate extension NSMutableData {
    func append(string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
