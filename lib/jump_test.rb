require File.join(File.dirname(__FILE__) + '/MT', 'tiny_vm')

vm = MT::TinyVM.new
C = vm.get_opcodes_reverted


def ts_positive
  code = []
  code << C[:JPR]
  code << 1
  code << C[:STOP] # trap
  10.times { code << C[:NOP] }
  code << C[:STOP]
end

def ts_zero
  code = []
  #super jump ^^
  code << C[:JPR]
  code << 0
  code << C[:STOP]
end

def ts_neg
  code = []
  code << C[:JPR]
  code << 2
  code << C[:STOP]
  code << C[:JPR]
  code << -1
  10.times { code << C[:NOP] }
  code << C[:STOP]
end
  


vm.dbg ts_zero