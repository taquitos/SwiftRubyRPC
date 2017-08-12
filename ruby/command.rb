require 'json'

module SwiftRubyRPC
  class Argument
    def initialize(json: nil)
      @name = json['name']
      @value = json['value']
    end

    def is_named
      return @name.to_s.length > 0
    end

    attr_reader :name
    attr_reader :value
  end

  class Command
    def initialize(json: nil)
      command_json = JSON.parse(json)
      @command_identifier = command_json['commandId']
      @method_name = command_json['methodName']

      args_json = command_json['args']
      @args = args_json.map do |arg|
        Argument.new(json: arg)
      end
    end

    attr_reader :command_id
    attr_reader :args
    attr_reader :method_name
  end
end
