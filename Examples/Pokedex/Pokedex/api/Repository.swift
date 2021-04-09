//
//  Repository.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import NetworkAgent

class Repository {
    private static var provider: NetworkAgentProvider<Api> = .init(plugins: [])
    
    static var pokemons: PokemonsRepository = .init(provider: provider)
    static var moves: MovesRepository = .init(provider: provider)
}
