//
//  PokemonsScreen.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import SwiftUI
import Combine

struct PokemonsScreen: View {
    
    @ObservedObject var viewModel: PokemonsViewModel = .init()
    
    var body: some View {
        NavigationView {
            List(viewModel.pokemons, id: \.name) { pokemon in
                Text(pokemon.name)
            }
            .navigationBarTitle("Pokemons")
        }
    }
}
