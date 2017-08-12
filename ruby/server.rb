require './command.rb'
require './command_executor.rb'
require 'socket'

module SwiftRubyRPC
  class Server
    def start
      server = TCPServer.open('localhost', 2000) # Socket to listen on port 2000
      print "Accepting connections\n"
      client = server.accept # Wait for a client to connect
      print "Client connected\n"

      loop do # Servers run forever
        str = client.recv(1_048_576) # 1024 * 1024
        if str == 'done'
          time = Time.new
          print "[#{time.usec}] :received done signal, shutting down\n"

          print "Done! Byeeeee\n"
          break
        end
        response_json = process_command(command_json: str)

        time = Time.new
        print "[#{time.usec}] :sending #{response_json}\n"
        client.puts(response_json) # Send some json to the client
      end
    end

    def process_command(command_json: nil)
      time = Time.new
      print "[#{time.usec}] :received command:#{command_json}\n"
      command = Command.new(json: command_json)

      return execute_command(command: command)
    end

    def execute_command(command: nil)
      time = Time.new
      print "[#{time.usec}] :parsed command name:#{command.name}\n"
      sleep(0.005)
      output = '{"payload":{"status": "ready_for_next"}}'
      return output
    end
  end
end

server = SwiftRubyRPC::Server.new

server.start
