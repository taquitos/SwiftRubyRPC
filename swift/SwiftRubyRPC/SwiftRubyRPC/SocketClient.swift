//
//  SocketClient.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 7/30/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Foundation

public enum SocketClientResponse: Error {
    case alreadyClosedSockets
    case malformedRequest
    case malformedResponse
    case serverError
    case commandTimeout(seconds: Int)
    case connectionFailure
    case success(returnedObject: String?)
}

class SocketClient: NSObject {

    enum SocketStatus {
        case ready
        case closed
    }

    static let connectTimeoutSeconds = 3
    static let commandTimeoutSeconds = 3
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

    weak private(set) var socketDelegate: SocketClientDelegateProtocol?

    public private(set) var socketStatus: SocketStatus

    init(host: String = "localhost", port: UInt32 = 2000, socketDelegate: SocketClientDelegateProtocol) {
        self.host = host
        self.port = port
        self.streamQueue = DispatchQueue(label: "streamQueue")
        self.socketStatus = .closed
        self.socketDelegate = socketDelegate
        super.init()
    }

    func connectAndOpenStreams() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        self.streamQueue.async {
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, self.host as CFString, self.port, &readStream, &writeStream)

            self.inputStream = readStream!.takeRetainedValue()
            self.outputStream = writeStream!.takeRetainedValue()

            self.inputStream.delegate = self
            self.outputStream.delegate = self

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

        let secondsToWait = DispatchTimeInterval.seconds(SocketClient.connectTimeoutSeconds)
        let connectTimeout = DispatchTime.now() + secondsToWait

        let timeoutResult = self.dispatchGroup.wait(timeout: connectTimeout)
        let failureMessage = "Couldn't connect to ruby process within: \(SocketClient.connectTimeoutSeconds) seconds"

        let success = testDispatchTimeoutResult(timeoutResult, failureMessage: failureMessage, timeToWait: secondsToWait)

        guard success else {
            self.socketDelegate?.commandExecuted(serverResponse: .connectionFailure)
            return
        }

        self.socketStatus = .ready
        self.socketDelegate?.connectionsOpened()
    }

    public func send(environmentVariables: EnvironmentVariables) {
        send(string: environmentVariables.json)
    }

    public func send(rubyCommand: RubyCommandable) {
        send(string: rubyCommand.json)
    }

    public func sendComplete() {
        sendAbort()
    }

    private func testDispatchTimeoutResult(_ timeoutResult: DispatchTimeoutResult, failureMessage: String, timeToWait: DispatchTimeInterval) -> Bool {
        switch timeoutResult {
        case .success:
            return true
        case .timedOut:
            log(message: "Timeout: \(failureMessage)")

            if case .seconds(let seconds) = timeToWait {
                socketDelegate?.commandExecuted(serverResponse: .commandTimeout(seconds: seconds))
            }
            return false
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
            socketDelegate?.commandExecuted(serverResponse: .alreadyClosedSockets)
            return
        }

        if string == SocketClient.doneToken {
            self.cleaningUpAfterDone = true
        }

        self.dispatchGroup.enter()
        streamQueue.async {
            let data = string.data(using: .utf8)!
            _ = data.withUnsafeBytes { self.outputStream.write($0, maxLength: data.count) }
        }

        let timeToWait = DispatchTimeInterval.seconds(SocketClient.commandTimeoutSeconds)
        let commandTimeout = DispatchTime.now() + timeToWait
        let timeoutResult =  self.dispatchGroup.wait(timeout: commandTimeout)

        if !self.cleaningUpAfterDone {
            // only wait if we aren't cleaning up, otherwise, we're in the process of exiting anyway
            _ = testDispatchTimeoutResult(timeoutResult, failureMessage: "Ruby process didn't return after: \(SocketClient.connectTimeoutSeconds) seconds", timeToWait: timeToWait)
        }
    }

    func sendAbort() {
        self.socketStatus = .closed

        stopInputSession()

        // and error occured, let's try to send the "done" message
        send(string: "done")

        stopOutputSession()
        self.socketDelegate?.connectionsClosed()
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
                verbose(message: "input stream error occurred")
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
                verbose(message: "input stream caused unrecognized event: \(eventCode)")
            }

        } else if aStream === self.outputStream {
            switch eventCode {
            case Stream.Event.openCompleted:
                self.dispatchGroup.leave()

            case Stream.Event.errorOccurred:
                // probably safe to close all the things because Ruby already disconnected
                verbose(message: "output stream recevied error")
                break

            case Stream.Event.endEncountered:
                // nothing special here
                break

            case Stream.Event.hasSpaceAvailable:
                // we don't care about this
                break

            default:
                verbose(message: "output stream caused unrecognized event: \(eventCode)")
            }
        }
    }

    func read() {
        var buffer = [UInt8](repeating: 0, count: maxReadLength)
        var output = ""
        while self.inputStream!.hasBytesAvailable {
            let bytesRead: Int = inputStream!.read(&buffer, maxLength: buffer.count)
            if bytesRead >= 0 {
                output += NSString(bytes: UnsafePointer(buffer), length: bytesRead, encoding: String.Encoding.utf8.rawValue)! as String
            } else {
                verbose(message: "Stream read() error")
            }
        }

        processResponse(string: output)
    }

    func handleFailure(message: [String]) {
        log(message: "Ruby process encountered a problem: \(message.joined(separator:"\n"))")
        sendAbort()
    }

    func processResponse(string: String) {
        guard string.characters.count > 0 else {
            self.handleFailure(message: ["empty response from ruby process"])
            return
        }

        let responseString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let socketResponse = SocketResponse(payload: responseString)
        verbose(message: "response is: \(responseString)")
        switch socketResponse.responseType {
        case .failure(let failureInformation):
            self.socketDelegate?.commandExecuted(serverResponse: .serverError)
            self.handleFailure(message: failureInformation)

        case .parseFailure(let failureInformation):
            self.socketDelegate?.commandExecuted(serverResponse: .malformedResponse)
            self.handleFailure(message: failureInformation)

        case .readyForNext(let returnedObject):
            self.socketDelegate?.commandExecuted(serverResponse: .success(returnedObject: returnedObject))
            // cool, ready for next command
            break

        }
        self.dispatchGroup.leave() // should now pull the next piece of work
    }
}
