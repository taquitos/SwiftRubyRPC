module SwiftRubyRPC
  class SwiftGenerator
    attr_reader :folder
    attr_reader :modules

    def initialize(folder, expected_modules)
      @folder = folder
      @modules = expected_modules
    end

    def generate
      class_folder = File.expand_path(folder)
      # relative_path = File.join(File.dirname(__FILE__), class_folder)
      Dir["#{class_folder}/**/*.rb"].each do |file|
        require file
      end

      classes = {}
      @modules.each do |some_module|
        module_object = Object.const_get(some_module)

        constants = module_object.constants.select { |c| module_object.const_get(c).kind_of? Class }
        constants = constants.map do |constant|
          module_object.const_get(constant)
        end

        classes[module_object] = constants
      end

      classes.each do |some_module, child_classes|
        child_classes.each do |a_class|
          inherited_methods = Object.class.instance_methods
          inherited_class_methods = Object.class.methods

          instance_methods = a_class.instance_methods - inherited_methods
          class_methods = a_class.methods - inherited_class_methods

          print "class: #{a_class}\n"
          print "instance_methods: #{instance_methods}\n"
          print "class_methods: #{class_methods}\n"
        end
      end
    end
  end
end
