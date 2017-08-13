//
//  ViewController.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 7/30/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet var inputTextField: NSTextField!
    @IBOutlet var sendButton: NSButton!
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var outputClearButton: NSButton!
    @IBOutlet var inputClearButton: NSButton!
    @IBOutlet var outputTextField: NSTextField!

    var thread: Thread?
    var socketClient: SocketClient?

    @IBAction func inputClearClicked(_ sender: NSButton) {
        self.inputTextField.stringValue = ""
    }

    @IBAction func outputClearClicked(_ sender: NSButton) {
        self.outputTextField.stringValue = ""
    }

    @IBAction func sendClicked(_ sender: NSButton) {
        guard let socketClient = self.socketClient else {
            return
        }

        self.sendButton.isEnabled = false
        self.inputTextField.isEnabled = false

        let command = buildCommand()

        DispatchQueue.global(qos: .userInitiated).async {

            socketClient.send(rubyCommand: command)
        }

    }

    func buildCommand() -> RubyCommand {
        var commandString = inputTextField.stringValue
        if commandString == "" {
            commandString = "{}"
        }

        let command = RubyCommand(name: "interactive app", json: commandString)
        return command
    }

    @IBAction func connectButtonClick(_ sender: NSButton) {
        if connectButton.title == "Disconnect" {
            log(message: "sending disconnect signal")
            self.connectButton.isEnabled = false
            DispatchQueue.global(qos: .userInitiated).async {
                self.socketClient?.sendComplete()
            }

        } else {
            log(message: "connecting")
            self.connectButton.isEnabled = false
            startSocketThread()
        }
    }

    func startSocketThread() {
        self.socketClient = SocketClient(socketDelegate: self)
        self.thread = Thread(target: self, selector: #selector(startSocketComs), object: nil)
        self.thread!.name = "socket thread"
        self.thread!.start()
    }

    override func viewWillDisappear() {
        if self.socketClient?.socketStatus == .ready {
            self.socketClient?.sendComplete()
        }

    }

    func startSocketComs() {
        guard let socketClient = self.socketClient else {
            return
        }

        socketClient.connectAndOpenStreams()
    }

    func log(message: String) {
        let timestamp = NSDate().timeIntervalSince1970
        self.outputTextField.stringValue += "[\(timestamp)]: \(message)\n"
    }
}

extension ViewController: SocketClientDelegateProtocol {
    func commandExecuted(error: SocketClientError?) {
        self.inputTextField.isEnabled = true
        self.inputClearButton.isEnabled = true
        self.sendButton.isEnabled = true

        guard let error = error else {
            log(message: "command executed")
            return
        }

        log(message: "error encountered while executing command:\n\(error)")

    }

    func connectionsOpened() {
        DispatchQueue.main.async {
            self.connectButton.title = "Disconnect"
            self.sendButton.isEnabled = true
            self.connectButton.isEnabled = true
            self.inputTextField.isEnabled = true
            self.log(message: "connected!")
        }
    }

    func connectionsClosed() {
        DispatchQueue.main.async {
            self.thread?.cancel()
            self.thread = nil
            self.socketClient = nil

            self.connectButton.title = "Connect"
            self.sendButton.isEnabled = false
            self.inputTextField.isEnabled = false
            self.connectButton.isEnabled = true
            self.log(message: "connection closed!")
        }
    }

}
