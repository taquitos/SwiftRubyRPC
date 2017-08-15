//
//  ViewController.swift
//  SwiftRubyRPC
//
//  Created by Joshua Liebowitz on 7/30/17.
//  Copyright © 2017 Joshua Liebowitz. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    enum CommandUIState {
        case disconnected
        case ready
        case waitingForResponse
        case connecting
    }

    var thread: Thread?
    var socketClient: SocketClient?

    @IBOutlet var inputTextView: NSTextView!
    @IBOutlet var sendButton: NSButton!
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var outputClearButton: NSButton!
    @IBOutlet var inputClearButton: NSButton!
    @IBOutlet var outputTextView: NSTextView!

    @IBAction func inputClearClicked(_ sender: NSButton) {
        self.inputTextView.string = self.startingJson
    }

    @IBAction func outputClearClicked(_ sender: NSButton) {
        self.outputTextView.string = ""
    }

    @IBAction func sendClicked(_ sender: NSButton) {
        guard let socketClient = self.socketClient else {
            return
        }

        self.sendButton.isEnabled = false
        self.inputTextView.isEditable = false

        let command = buildCommand()
        DispatchQueue.global(qos: .userInitiated).async {
            socketClient.send(rubyCommand: command)
        }
    }

    @IBAction func connectButtonClick(_ sender: NSButton) {
        if connectButton.title == "Disconnect" {
            log(message: "sending disconnect signal")
            prepareUI(state: .waitingForResponse)
            DispatchQueue.global(qos: .userInitiated).async {
                self.socketClient?.sendComplete()
            }
        } else {
            log(message: "connecting")
            prepareUI(state: .connecting)
            startSocketThread()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.prepareUI(state: .disconnected)
        self.inputTextView.string = self.startingJson
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.inputTextView.isAutomaticQuoteSubstitutionEnabled = false
        self.inputTextView.enabledTextCheckingTypes = 0
        if #available(OSX 10.12.2, *) {
            self.inputTextView.isAutomaticTextCompletionEnabled = false
        }
    }

    var startingJson: String {
        let commandIDJson = "\"commandID\" : \"testCommand\""
        let methodNameJson = "\"methodName\" : \"\""
        let classNameJson = "\"className\" : \"\""
        let argsJson = "\"args\" : [{\"name\" : \"\", \"value\" : \"\"}]"
        let startingJson = "{\n \(commandIDJson),\n \(classNameJson), \n \(methodNameJson), \n \(argsJson)\n}"
        return startingJson
    }

    func prepareUI(state: CommandUIState) {
        switch state {
        case .ready:
            self.connectButton.title = "Disconnect"
            self.sendButton.isEnabled = true
            self.connectButton.isEnabled = true
            self.inputTextView.isEditable = true

        case .disconnected:
            self.connectButton.title = "Connect"
            self.sendButton.isEnabled = false
            self.connectButton.isEnabled = true
            self.inputTextView.isEditable = true

        case .waitingForResponse, .connecting:
            self.sendButton.isEnabled = false
            self.connectButton.isEnabled = false
            self.inputTextView.isEditable = false
        }
    }

    override func viewWillDisappear() {
        if self.socketClient?.socketStatus == .ready {
            self.socketClient?.sendComplete()
        }
    }

    func log(message: String) {
        let timestamp = NSDate().timeIntervalSince1970
        let message = "[\(timestamp)]: \(message)\n"

        DispatchQueue.main.async {
            let outputString: String
            if let string = self.outputTextView.string {
                outputString = string + message
            } else {
                outputString = message
            }
            self.outputTextView.string = outputString
        }
    }
}

// extension that handles all the server stuff
extension ViewController {
    func startSocketThread() {
        self.socketClient = SocketClient(socketDelegate: self)
        self.thread = Thread(target: self, selector: #selector(startSocketComs), object: nil)
        self.thread!.name = "socket thread"
        self.thread!.start()
    }

    func startSocketComs() {
        guard let socketClient = self.socketClient else {
            return
        }

        socketClient.connectAndOpenStreams()
    }

    func buildCommand() -> RubyCommandable {
        guard let commandString = inputTextView.string else {
            return RubyCommandJson(json: "{}")
        }

        if commandString == "" {
            return RubyCommandJson(json: "{}")
        }

        return RubyCommandJson(json: commandString)
    }
}

extension ViewController: SocketClientDelegateProtocol {
    func commandExecuted(error: SocketClientError?) {
        prepareUI(state: .ready)

        guard let error = error else {
            log(message: "command executed")
            return
        }

        log(message: "error encountered while executing command:\n\(error)")
    }

    func connectionsOpened() {
        DispatchQueue.main.async {
            self.prepareUI(state: .ready)

            self.log(message: "connected!")
        }
    }

    func connectionsClosed() {
        DispatchQueue.main.async {
            self.thread?.cancel()
            self.thread = nil
            self.socketClient = nil

            self.prepareUI(state: .disconnected)

            self.log(message: "connection closed!")
        }
    }
}

struct RubyCommandJson: RubyCommandable {
    let json: String
}
