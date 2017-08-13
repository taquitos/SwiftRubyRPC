//
//  RubyCommand.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 8/4/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Foundation

struct RubyCommand {
    let name: String
    let json: String

//    init(name: String, json: String) {
//        self.name = name
//        self.json = json
//    }

//    var json: String {
//
//        return "{\"name\": \"\(self.name)\"}"
//        do {
//            let jsonData = try JSONSerialization.data(withJSONObject: self)
//            let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)!
//            return jsonString as String
//        } catch {
//            print("Unable to parse ruby command: \(error.localizedDescription)")
//            fatalError()
//        }
//    }
}
