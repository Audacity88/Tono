//
//  TonoApp.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import SwiftUI

@main
struct TonoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
