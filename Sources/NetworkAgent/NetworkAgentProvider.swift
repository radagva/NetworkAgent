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
        let request = configure(endpoint: endpoint)
        return try await agent.run(request, plugins: plugins)
    }

    // MARK: Build Request object
    private func configure(endpoint: E) -> URLRequest {
        let boundary = "Boundary-\(UUID().uuidString)"

        /// CREATION OF THE URLRequest / DOMAIN BASE URL MIXING WITH URL PATH
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent(endpoint.path))

        /// HTTP HEADERS CONFIGURATION [String: String]
        endpoint.headers.forEach({
            var value = $0.value
            if case .upload = endpoint.task {
                value = "\($0.value); boundary=\(boundary)"
            }

            request.addValue(value, forHTTPHeaderField: $0.key)
        })

        /// HTTP METHOD CONFIGURATION <GET, POST, PUT, PATCH, DELETE>
        request.httpMethod = endpoint.method.rawValue.uppercased()

        /// HTTP BODY CONFIGURATION [String: Any] <- Data
        if case let .requestAttributes(attributes, encoding) = endpoint.task {

            switch encoding {
            case .json:
                request.httpBody = try? JSONSerialization.data(withJSONObject: attributes, options: .prettyPrinted)
            case .url:
                var components = URLComponents(string: request.url?.absoluteString ?? endpoint.baseURL.absoluteString)!
                components.queryItems = attributes.keys.map { URLQueryItem(name: $0, value: String(attributes[$0])) }
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

    private func makeUploadBoundaryField(name: String, value: Data, using boundary: String) -> String {
        var field = "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        field += "\r\n"
        field += "\(String(data: value, encoding: .utf8) ?? "")\r\n"
        return field
    }

    private func makeUploadBoundaryData(field: String, file name: String, myme: String, fileData: Data, using boundary: String) -> Data {
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

fileprivate extension String {
    init(_ item: Any?) {
        self.init()
        if let item = item {
            self = "\(item)"
        }
    }
}
