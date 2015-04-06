class RubyProcess
  #Evalulates the given string in the process.
  #===Examples
  # rp.str_eval("return 10").__rp_marshal #=> 10
  def str_eval(str)
    send(cmd: :str_eval, str: str)
  end

  #Process-method for 'str_eval'.
  def cmd_str_eval(obj)
    #Lamda is used here because 'return' might be used in evalled code and thereby return an unhandeled object.
    return handle_return_object(lambda{
      eval(obj[:str])
    }.call)
  end
end
