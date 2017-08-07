require 'json'

class Command
  def initialize(json: nil)
    command_json = JSON.parse(json)
    @name = command_json['name']
  end

  attr_reader :name
end
