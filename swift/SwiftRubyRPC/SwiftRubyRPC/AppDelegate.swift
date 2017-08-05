//
//  AppDelegate.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 7/30/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Cocoa

let socketClient = SocketClient()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var thread: Thread!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        thread = Thread(target: self, selector: #selector(startSocketComs), object: nil)
        thread.name = "socket thread"
        thread.start()
    }

    func startSocketComs() {
        socketClient.connectAndOpenStreams()
        Commands.execute()
        print("Cleaning up and exiting")
        exit(0)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if socketClient.socketStatus == .ready {
            socketClient.sendComplete()
        }
    }
}
