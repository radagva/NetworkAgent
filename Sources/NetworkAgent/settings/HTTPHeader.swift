//
//  HTTPHeader.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public enum HTTPHeader {
    case contentType(_ header: HTTPHeaderType)
    case accept(_ header: HTTPHeaderType)
    case authorization(_ header: HTTPAuthorizationType)
    case raw(_ string: String)
    
    
    var description: String {
        switch self {
        case .contentType: return "Content-Type"
        case .accept: return "Accept"
        case .authorization: return "Authorization"
        case let .raw(string): return "\(string)"
        }
    }
    
    public enum HTTPHeaderType {
        case applicationJson
        case multipart(_ type: HTTPMultipartType)
        case raw(_ string: String)
        
        var description: String {
            switch self {
            case .applicationJson: return "application/json"
            case let .multipart(multipart): return "multipart/\(multipart.description)"
            case let .raw(string): return "\(string)"
            }
        }
    }
    
    public enum HTTPMultipartType {
        case formData
        case raw(_ string: String)
        
        var description: String {
            switch self {
            case .formData: return "form-data"
            case let .raw(string): return "\(string)"
            }
        }
    }
    
    public enum HTTPAuthorizationType {
        case jwt(token: String)
        case raw(_ string: String)
        
        var description: String {
            switch self {
            case let .jwt(token): return "\(token)"
            case let .raw(string): return "\(string)"
            }
        }
    }
}
