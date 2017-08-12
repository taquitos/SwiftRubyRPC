require './command.rb'

module SwiftRubyRPC
  class CommandExecutor
    class << self
      def execute(command: nil, target_object: nil)
        command_id = command.command_id
        method_name = command.method_name
        args = command.args
        print "executing command with identifier #{command_id}\nmethod: #{method_name}\nargs: #{args}\n"

        transformed_arg_list = []
        args.each do |arg|
          if arg.is_named
            transformed_arg_list << { arg.name.to_sym => arg.value }
          else
            transformed_arg_list << arg.value
          end
        end

        target_object.public_send(method_name, *transformed_arg_list)
      end
    end
  end
end
