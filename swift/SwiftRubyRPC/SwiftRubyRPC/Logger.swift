//
//  Logger.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 9/18/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Foundation

let logger: Logger = {
    return Logger()
}()

class Logger {
    enum LogMode {
        init(logMode: String) {
            switch logMode {
            case "normal", "default":
                self = .normal
            case "verbose":
                self = .verbose
            default:
                logger.log(message: "unrecognized log mode: \(logMode), defaulting to 'normal'")
                self = .normal
            }
        }
        case normal
        case verbose
    }

    public static var logMode: LogMode = .normal

    func log(message: String) {
        let timestamp = NSDate().timeIntervalSince1970
        print("[\(timestamp)]: \(message)")
    }

    func verbose(message: String) {
        if Logger.logMode == .verbose {
            let timestamp = NSDate().timeIntervalSince1970
            print("[\(timestamp)]: \(message)")
        }
    }
}

func log(message: String) {
    logger.log(message: message)
}

func verbose(message: String) {
    logger.verbose(message: message)
}
