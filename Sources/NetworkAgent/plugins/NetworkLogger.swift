//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation
import OSLog

@available(macOS 12, *) @available(iOS 15, *)
fileprivate extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")
}

fileprivate extension JSONSerialization {
    static func prettyPrinted(data: Data?) -> String? {
        guard let data else { return nil }
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(decoding: jsonData, as: UTF8.self)
        } else {
            return nil
        }
    }
}

@available(macOS 12, *) @available(iOS 15, *)
public class NetworkLogger: NetworkAgentPlugin {
    public func onRequest(_ request: inout URLRequest) {
        request.setValue("Bearer XYZ", forHTTPHeaderField: "Authorization")
    }
    
    public func onResponse(_ response: HTTPURLResponse, receiving data: Data, from request: URLRequest) {
        let url = request.url?.absoluteString
        let headers = request.allHTTPHeaderFields
        let body = JSONSerialization.prettyPrinted(data: request.httpBody)
        let content = JSONSerialization.prettyPrinted(data: data)
        
        let dict = [
            ("URL", url as Any?),
            ("HEADERS", headers as Any?),
            ("BODY", body as Any?),
            ("RESPONSE", content as Any?)
        ].filter { $0.1 != nil }
        
        let solved = dict.map { "\($0.0): \(String(describing: $0.1!))" }.joined(separator: "\n")
        
        Logger.viewCycle.info("\(solved)")
    }
}
