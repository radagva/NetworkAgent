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
        /// will display everything (Request, Response and errors)
        case verbose
        /// will display just network responses
        case responses
        /// will display just network request configuration
        case requests
        /// will display only network and URL errors
        case errors
    }
    
    private var options: Set<LogType>!
    
    init(options types: Set<LogType> = .init()) {
        options = types
    }
    
    // Request handler
    func onRequest(_ request: URLRequest, with configuration: RequestConfiguration) {
        if options.contains(.requests) || options.contains(.verbose) {
            printFormatting(label: "URL", "\(request.url)")
            printFormatting(label: "HEADERS", "\(request.allHTTPHeaderFields)")
            printFormatting(label: "METHOD", "\(request.httpMethod)")
            if let method = request.httpMethod, method != "GET" {
                if let body = request.httpBody {
                    printFormatting(label: "BODY", "\(json: body)")
                } else {
                    printFormatting(label: "UNABLE TO PARSE BODY")
                }
            }
        }
    }
    
    // Response handler
    func onResponse(_ response: HTTPURLResponse, with payload: Data) {
        if options.contains(.responses) || options.contains(.verbose) {
            printFormatting(label: "STATUS CODE =>", response.statusCode)
            printFormatting(label: "PAYLOAD =>", "\(json: payload)")
        }
    }
    
    // Errors handler
    func onResponse(_ response: HTTPURLResponse?, with payload: Data?, receiving error: NetworkAgent.NetworkError, from endpoint: NetworkAgentEndpoint) {
        if options.contains(.errors) || options.contains(.verbose) {
            
            if let response = response, let payload = payload {
                printFormatting(label: "STATUS CODE =>", response.statusCode)
                printFormatting(label: 200...299 ~= response.statusCode ? "PAYLOAD =>" : "ERROR =>", "\(json: payload)")
            }
            
            if case let .urlError(error) = error {
                switch error.code {
                case .notConnectedToInternet: print("YOU ARE NOT CONNECTED TO INTERNET")
                case .timedOut: print("REQUEST TIME OUT for endpoint: \(endpoint.baseURL)\(endpoint.path)")
                default: print("ANOTHER UNHANDLED URL ERROR: \(error)")
                }
                return
            }
            
            if case let .decodingError(error) = error {
                switch error {
                case .keyNotFound(let keyPath, let context): printFormatting(label: "DECODING ERROR FOR KEY: \(keyPath). AT CONTEXT: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context): printFormatting(label: "DECODING ERROR FOR TYPE: \(type). DEBUG INFO: \(context.debugDescription). AT CONTEXT: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                default: print("ANOTHER UNHANDLED DECODING ERROR: \(error)")
                }
                return
            }
            
            if case let .unprocesableEntity(_, description) = error {
                if let data = description.data(using: .utf8) {
                    printFormatting(label: "UNPROCESABLE ENTITY =>", "\(json: data)")
                    return
                }
            }
            
            printFormatting(label: "ANOTHER ERROR", error)
        }
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
