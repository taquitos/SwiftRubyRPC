//
//  SocketClient.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 7/30/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Foundation

class SocketClient: NSObject {

    enum SocketStatus {
        case ready
        case closed
    }

    static let connectTimeoutSeconds = 1
    static let commandTimeoutSeconds = 1
    static let doneToken = "done"

    fileprivate var inputStream: InputStream!
    fileprivate var outputStream: OutputStream!
    fileprivate var cleaningUpAfterDone = false
    fileprivate let dispatchGroup: DispatchGroup = DispatchGroup()

    private let streamQueue: DispatchQueue
    private let host: String
    private let port: UInt32

    // TODO: change it to something reasonable. Keeping it at 1 to test
    let maxReadLength = 1 // max for ipc on 10.12 is kern.ipc.maxsockbuf: 8388608 ($sysctl kern.ipc.maxsockbuf)

    public private(set) var socketStatus: SocketStatus

    init(host: String = "localhost", port: UInt32 = 2000) {
        self.host = host
        self.port = port
        self.streamQueue = DispatchQueue(label: "streamQueue")
        self.socketStatus = .closed
        super.init()
    }

    func connectAndOpenStreams() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        self.streamQueue.sync {
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, self.host as CFString, self.port, &readStream, &writeStream)

            inputStream = readStream!.takeRetainedValue()
            outputStream = writeStream!.takeRetainedValue()

            inputStream.delegate = self
            outputStream.delegate = self

            self.inputStream.schedule(in: .main, forMode: .defaultRunLoopMode)
            self.outputStream.schedule(in: .main, forMode: .defaultRunLoopMode)
        }

        self.dispatchGroup.enter()
        self.streamQueue.async {
            self.inputStream.open()
        }

        self.dispatchGroup.enter()
        self.streamQueue.async {
            self.outputStream.open()
        }

        let connectTimeout = DispatchTime.now() + DispatchTimeInterval.seconds(SocketClient.connectTimeoutSeconds)
        let timeoutResult = self.dispatchGroup.wait(timeout: connectTimeout)

        testDispatchTimeoutResult(timeoutResult, failureMessage: "Couldn't connect to ruby process within: \(SocketClient.connectTimeoutSeconds) seconds")
        sleep(1) // just to ensure we are actually running in a different thread
        self.socketStatus = .ready
        print("done opening, ready to send and receive")
    }

    public func send(environmentVariables: EnvironmentVariables) {
        send(string: environmentVariables.json)
    }

    public func send(rubyCommand: RubyCommand) {
        send(string: rubyCommand.json)
    }

    public func sendComplete() {
        sendAbort()
    }

    private func testDispatchTimeoutResult(_ timeoutResult: DispatchTimeoutResult, failureMessage: String) {
        switch timeoutResult {
        case .success:
            break
        case .timedOut:
            print("Timeout: \(failureMessage)")
            fatalError()
        }
    }

    private func stopInputSession() {
        inputStream.close()
    }

    private func stopOutputSession() {
        outputStream.close()
    }

    private func send(string: String) {
        guard !self.cleaningUpAfterDone else {
            // This will happen after we abort if there are commands waiting to be executed
            // Need to check state of SocketClient in command runner to make sure we can accept `send`
            fatalError("Attempt to send command: \(string)\nafter we already told the ruby server we were done.")
        }

        if string == SocketClient.doneToken {
            self.cleaningUpAfterDone = true
        }

        self.dispatchGroup.enter()
        streamQueue.async {
            let data = string.data(using: .utf8)!
            _ = data.withUnsafeBytes { self.outputStream.write($0, maxLength: data.count) }
        }

        let commandTimeout = DispatchTime.now() + DispatchTimeInterval.seconds(SocketClient.commandTimeoutSeconds)
        let timeoutResult =  self.dispatchGroup.wait(timeout: commandTimeout)

        if !self.cleaningUpAfterDone {
            // only wait if we aren't cleaning up, otherwise, we're in the process of exiting anyway
            testDispatchTimeoutResult(timeoutResult, failureMessage: "Ruby process didn't return after: \(SocketClient.connectTimeoutSeconds) seconds")
        }
    }

    func sendAbort() {
        self.socketStatus = .closed

        stopInputSession()

        // and error occured, let's try to send the "done" message
        send(string: "done")

        stopOutputSession()
    }
}

extension SocketClient: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard !self.cleaningUpAfterDone else {
            // Still getting response from server eventhough we are done. 
            // No big deal, we're closing the streams anyway. 
            // That being said, we need to balance out the dispatchGroups
            self.dispatchGroup.leave()
            return
        }

        if aStream === self.inputStream {
            switch eventCode {
            case Stream.Event.openCompleted:
                self.dispatchGroup.leave()

            case Stream.Event.errorOccurred:
                print("error occurred")
                sendAbort()

            case Stream.Event.hasBytesAvailable:
                read()

            case Stream.Event.endEncountered:
                // nothing special here
                break

            case Stream.Event.hasSpaceAvailable:
                // we don't care about this
                break

            default:
                print("input stream caused unrecognized event: \(eventCode)")
            }

        } else if aStream === self.outputStream {
            switch eventCode {
            case Stream.Event.openCompleted:
                self.dispatchGroup.leave()

            case Stream.Event.errorOccurred:
                print("error occurred")
                // safe to close all the things because Ruby already disconnected

            case Stream.Event.endEncountered:
                // nothing special here
                break

            case Stream.Event.hasSpaceAvailable:
                // we don't care about this
                break

            default:
                print("output stream caused unrecognized event: \(eventCode)")
            }
        }
    }

    func read() {
        var buffer = [UInt8](repeating: 0, count: maxReadLength)
        var output = ""
        while (self.inputStream!.hasBytesAvailable) {
            let bytesRead: Int = inputStream!.read(&buffer, maxLength: buffer.count)
            if bytesRead >= 0 {
                output += NSString(bytes: UnsafePointer(buffer), length: bytesRead, encoding: String.Encoding.utf8.rawValue)! as String
            } else {
                print("Stream read() error")
            }
        }

        processResponse(string: output)
    }

    func handleFailure(message: String) {
        print("Ruby process encountered a problem:\(message)")
        sendAbort()
    }

    func processResponse(string: String) {
        guard string.characters.count > 0 else {
            self.handleFailure(message: "empty response from ruby process")
            return
        }

        var messages = 0
        string.enumerateLines { (messageString, _) in
            guard messages == 0 else {
                print("Received too many messages, something is wrong, please file an issue!")
                print("Received: \(string)")
                self.sendAbort()
                return
            }

            messages += 1
            let socketResponse = SocketResponse(payload: messageString)

            switch socketResponse.responseType {
            case .failure(let failureInformation):
                self.handleFailure(message: failureInformation)

            case .parseFailure(let failureInformation):
                self.handleFailure(message: failureInformation)

            case .readyForNext:
                // cool, ready for next command
                break
            }
        }
        self.dispatchGroup.leave() // should now pull the next piece of work
    }
}
