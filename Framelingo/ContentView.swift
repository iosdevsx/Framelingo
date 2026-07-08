//
//  ContentView.swift
//  Framelingo
//
//  Created by Юрий Логинов on 27.04.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainNavigationView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
