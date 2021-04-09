//
//  PokemonsViewModel.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import Combine

class PokemonsViewModel: ObservableObject {
    @Published var pokemons: [Pokemon] = []
    
    init() {
        Repository.pokemons.index(query: ["offset": 20, "limit": 20])
            .map({ (pagination: Pagination<Pokemon>) in
                return self.pokemons + pagination.results
            })
            .catch { _ in Just(self.pokemons) }
            .assign(to: &$pokemons)
    }
}
