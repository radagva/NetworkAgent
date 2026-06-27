//
//  File.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation
import NetworkAgent

class AgentLogger: NetworkAgentPlugin {

    enum LogType {
        /// will display everything (Request and Response)
        case verbose
        /// will display just network responses
        case responses
        /// will display just network request configuration
        case requests
    }

    private var options: Set<LogType>!

    init(options types: Set<LogType> = .init()) {
        options = types
    }

    // Request interceptor
    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest {
        if options.contains(.requests) || options.contains(.verbose) {
            printFormatting(label: "URL", "\(String(describing: request.url))")
            printFormatting(label: "HEADERS", "\(String(describing: request.allHTTPHeaderFields))")
            printFormatting(label: "METHOD", "\(String(describing: request.httpMethod))")
            if let method = request.httpMethod, method != "GET" {
                if let body = request.httpBody {
                    printFormatting(label: "BODY", "\(json: body)")
                } else {
                    printFormatting(label: "UNABLE TO PARSE BODY")
                }
            }
        }
        return request
    }

    // Response interceptor
    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse) {
        if options.contains(.responses) || options.contains(.verbose) {
            if let httpResponse = response as? HTTPURLResponse {
                printFormatting(label: "STATUS CODE =>", httpResponse.statusCode)
            }
            printFormatting(label: "PAYLOAD =>", "\(json: data)")
        }
        return (data: data, response: response)
    }

    private func printFormatting(label: String, _ data: Any? = nil) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        if let data = data {
            print("AGENT: \(formatter.string(from: Date()))", label, "\(data)")
        } else {
            print("AGENT: \(formatter.string(from: Date()))", label)
        }
    }
}
