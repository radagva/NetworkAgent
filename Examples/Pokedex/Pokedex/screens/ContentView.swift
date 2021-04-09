//
//  ContentView.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PokemonsScreen()
                .tabItem {
                    Text("Pokemons")
                }
            MovesScreen()
                .tabItem {
                    Text("Moves")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
