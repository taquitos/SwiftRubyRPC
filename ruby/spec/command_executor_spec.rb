require './command.rb'
require './command_executor.rb'
require 'test_objects/some_test_class.rb'

module SwiftRubyRPC
  describe SwiftRubyRPC do
    describe SwiftRubyRPC::CommandExecutor do
      it "successfully executes a command with no parameters" do
        target_object = SomeTestClass.new
        command_json = '{
          "commandID" : "fakeID",
          "methodName" : "something_no_args"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command, target_object: target_object)
        expect(output).to eq("something no args")
      end

      it "successfully executes a command with one non-named parameter" do
        target_object = SomeTestClass.new
        command_json = '{
          "commandID" : "fakeID",
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
          "commandID" : "fakeID",
          "args" : [{ "value" : "expected return", "name" : "text" }],
          "methodName" : "something_one_arg_named"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command, target_object: target_object)
        expect(output).to eq("expected return")
      end

      it "successfully executes a command with one unnamed parameter and one named parameter" do
        target_object = SomeTestClass.new
        command_json = '{
          "commandID" : "fakeID",
          "args" : [{ "value" : "my " }, { "value" : "expected return", "name" : "text" }],
          "methodName" : "two_args_one_named"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command, target_object: target_object)
        expect(output).to eq("my expected return")
      end

      it "successfully executes a class-level command with one non-named parameter" do
        command_json = '{
          "commandID" : "fakeID",
          "args" : [{ "value" : "expected return" }],
          "methodName" : "class_something_one_arg",
          "className" : "SomeTestClass"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command)
        expect(output).to eq("class expected return")
      end

      it "successfully executes a class-level command with no parameters" do
        command_json = '{
          "commandID" : "fakeID",
          "methodName" : "class_something_no_args",
          "className" : "SomeTestClass"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command)
        expect(output).to eq("class something no args")
      end

      it "successfully executes a command with one unnamed parameter and one named parameter" do
        command_json = '{
          "commandID" : "fakeID",
          "args" : [{ "value" : "my " }, { "value" : "expected return", "name" : "text" }],
          "methodName" : "class_two_args_one_named",
          "className" : "SomeTestClass"
        }'

        command = Command.new(json: command_json)
        output = CommandExecutor.execute(command: command)
        expect(output).to eq("class my expected return")
      end
    end
  end
end
