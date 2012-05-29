class Ruby_process
  #Returns a numeric value like a integer. This methods exists because it isnt possible to do: "Integer.new(5)".
  #===Examples
  # proxy_int = rp.numeric(5)
  # proxy_int.__rp_marshal #=> 5
  def numeric(val)
    return send(:cmd => :numeric, :val => val)
  end
  
  #Process-method for the 'numeric'-method.
  def cmd_numeric(obj)
    return handle_return_object(obj[:val].to_i)
  end
end