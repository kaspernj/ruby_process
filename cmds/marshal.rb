class Ruby_process
  #This command returns an object as a marshalled string, so it can be re-created on the other side.
  def cmd_obj_marshal(obj)
    myobj = @objects[obj[:id]]
    raise "Object by that ID does not exist: '#{obj[:id]}'." if !myobj
    return Marshal.dump(myobj)
  end
end
