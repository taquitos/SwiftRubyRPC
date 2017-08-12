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

  def self.class_something_no_args
    return "class something no args"
  end

  def self.class_something_one_arg(text = nil)
    return text
  end
end
