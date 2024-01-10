//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation

protocol NetworkAgentPlugin {
    func onRequest()
    func onResponse()
    func onResponseError()
}
