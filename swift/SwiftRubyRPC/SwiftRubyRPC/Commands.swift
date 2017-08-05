//
//  Commands.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 8/4/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Foundation

struct Commands: CommandFile {

    static let environmentVariables: EnvironmentVariables? = EnvironmentVariables(variableMap: ["SOME_VAR_NAME": "SOME_VAR_VALUE"])
    static let execute: () -> Void = {

        let commands = [
            RubyCommand(name: "First command"),
            RubyCommand(name: "Second command"),
            RubyCommand(name: "Third command"),
            RubyCommand(name: "Fourth command")
        ]

        print("sending env vars")
        socketClient.send(environmentVariables: environmentVariables!)

        for command in commands {
            guard socketClient.socketStatus == .ready else {
                print("command sending interrupted by socket status")
                break
            }
            print("sending command named:\(command.name)")
            socketClient.send(rubyCommand: command)
        }

        if socketClient.socketStatus == .ready {
            socketClient.sendComplete()
        }
    }

}
