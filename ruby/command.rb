require 'json'
class Command
	def initialize(json: nil)
		command_json = JSON.parse(json)
		@name = command_json['name']
  end

  def name
  	return @name
  end
end