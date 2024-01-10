//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation

public enum HTTPError: Error {
    
    enum ErrorCodeType {
        case redirect
        case badRequest
        case internalServerError
    }
    
    case redirect(_ response: HTTPURLResponse, data: Data)
    case badRequest(_ response: HTTPURLResponse, data: Data)
    case internalServerError(_ response: HTTPURLResponse, data: Data)
}
