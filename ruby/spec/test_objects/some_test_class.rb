module TestClasses
  class SomeTestClass
    def something_no_args
      return "something no args"
    end

    # not named
    def something_one_arg(text)
      return text
    end

    def something_one_arg_named(text: nil)
      return text
    end

    def two_args_one_named(tacos, text: nil)
      return tacos + text
    end

    def self.class_something_no_args
      return "class something no args"
    end

    def self.class_something_one_arg(text = nil)
      return "class " + text
    end

    def self.class_two_args_one_named(tacos, text: nil)
      return "class " + tacos + text
    end
  end
end
