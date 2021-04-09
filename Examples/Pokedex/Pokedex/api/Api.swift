//
//  Api.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import NetworkAgent

enum Api {
    case pokemons(query: [String: Any])
    case pokemon(id: Int, query: [String: Any])
    
    case moves(query: [String: Any])
    case move(id: Int, query: [String: Any])
}

extension Api: NetworkAgentEndpoint {
    
    var baseURL: URL {
        return URL(string: "https://pokeapi.co/api/v2")!
    }
    
    var path: String {
        switch self {
        case .pokemons: return "/pokemon"
        case let .pokemon(id, _): return "/pokemon/\(id)"
        case .moves: return "/move"
        case let .move(id, _): return "/move/\(id)"
        }
    }
    
    var headers: [String : String] {
        return ["Content-Type": "application/json"]
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var task: HTTPTask {
        switch self {
        case let .pokemons(query): return .requestAttributes(attributes: query, encoding: .url)
        case let .pokemon(_, query): return .requestAttributes(attributes: query, encoding: .url)
        case let .moves(query): return .requestAttributes(attributes: query, encoding: .url)
        case let .move(_, query): return .requestAttributes(attributes: query, encoding: .url)
        }
    }
}
