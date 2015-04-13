class RubyProcess
  #This command returns an object as a marshalled string, so it can be re-created on the other side.
  def cmd_obj_marshal(obj)
    myobj = proxyobj_object(obj[:id])
    return Marshal.dump(myobj)
  end
end
