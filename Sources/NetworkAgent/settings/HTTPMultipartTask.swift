//
//  HTTPMultipartTask.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation

public struct HTTPMultipartTask {
    var data: Data
    var name: String
    var filename: String
    var mymetype: String?
//    var mymetype: MymeType? = nil
    
    public enum MymeType {
        case png
        case jpg
        case raw(_ type: String)
        
        var description: String {
            switch self {
            case let .raw(type): return type
            default: return "\(self)"
            }
        }
    }
    
    public init(data: Data, name: String, filename: String, mymetype: String? = nil) {
        self.data = data
        self.name = name
        self.filename = filename
        self.mymetype = mymetype
    }
}
