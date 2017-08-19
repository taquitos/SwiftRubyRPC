require './swift_generator.rb'

module SwiftRubyRPC
  describe SwiftGenerator do
    describe SwiftRubyRPC::SwiftGenerator do
      it "successfully executes a command with no parameters" do
        generator = SwiftGenerator.new("spec/test_objects", [:TestClasses])
        generator.generate
      end
    end
  end
end
