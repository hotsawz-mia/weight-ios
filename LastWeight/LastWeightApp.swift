//
//  LastWeightApp.swift
//  Last Weight
//
//  Created by Mark James on 22/03/2025.
//

import SwiftUI // Import the SwiftUI framework so we can build the app's UI

@main // This marks the entry point of the app – there can only be one @main in the project
struct LastWeightApp: App { // Define the main app structure, conforming to the App protocol
    var body: some Scene { // The main scene that defines the app's UI window(s)
        WindowGroup { // A container that manages a group of windows for this scene
            ContentView() // This is the root view that will appear when the app launches
        }
    }
}
