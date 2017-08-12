require './command.rb'
require './command_executor.rb'
require 'test_objects/some_test_class.rb'

module SwiftRubyRPC
  describe SwiftRubyRPC do
    describe SwiftRubyRPC::CommandExecutor do
      it "successfully executes a command with one non-named parameter" do
        target_object = SomeTestClass.new
        command_json = '{
          "commandId" : "ID",
          "args" : [{ "value" : "expected return" }],
          "methodName" : "something_one_arg"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command, target_object: target_object)
        expect(output).to eq("expected return")
      end

      it "successfully executes a command with one named parameter" do
        target_object = SomeTestClass.new
        command_json = '{
          "name" : "ID",
          "args" : [{ "value" : "expected return", "name" : "text" }],
          "methodName" : "something_one_arg_named"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command, target_object: target_object)
        expect(output).to eq("expected return")
      end
    end
  end
end