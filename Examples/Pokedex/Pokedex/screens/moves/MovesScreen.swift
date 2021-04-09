//
//  MovesScreen.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import SwiftUI

struct MovesScreen: View {
    @ObservedObject var viewModel: MovesViewModel = .init()
    
    var body: some View {
        NavigationView {
            List(viewModel.moves, id: \.name) { move in
                Text(move.name)
            }
            .navigationBarTitle("Moves")
        }
    }
}
