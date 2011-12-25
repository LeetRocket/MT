module MT

  #Tiny VM
  #Works with 16 bit signed numbers
  class TinyVM
    
    BASE    = 256
    STACK_SIZE = 65536
  
    def initialize()
      @STOP = false
      
      #FLAGS
      @ZF = false   #zero
      @CF = false   #carry
      @LF = false   #left overflow
      @RF = false   #right overflow
    
      @byte_code = []
      @ptr = 0  #current programm byte
      @stack = []
    
      @MEM = [] #Memory
    
      @ops = {}
      @ops[:NOP]   = lambda { nop }
      @ops[:PSH]   = lambda { psh }
      @ops[:POP]   = lambda { pop }
      @ops[:ADD]   = lambda { add }  
      @ops[:SUB]   = lambda { sub }
      @ops[:MUL]   = lambda { mul }
      @ops[:DIV]   = lambda { div }
      
      @ops[:AND]   = lambda { o_and }
      @ops[:OR]    = lambda { o_or }
      @ops[:NOT]   = lambda { o_not }
      
      
      @ops[:MOD]   = lambda { mod }
      @ops[:STOP]  = lambda { stop }
      @ops[:PRT]   = lambda { prt }
      @ops[:PRTT]  = lambda { prtt }
      @ops[:PRTP]  = lambda { prtp }
      @ops[:POPV]  = lambda { popv }
      @ops[:PSHV]  = lambda { pshv }
      
      @opcodes = {
        0x00  =>  :NOP,
        0x01  =>  :PSH, # 2 push nb
        0x02  =>  :POP,  # 1 
        0x03  =>  :ADD,  # 1 top = st0 + st1
        0x04  =>  :SUB,  # 1 top = st1 - st0
        0x05  =>  :MUL,  # 1 top = st0 * st1
        0x06  =>  :DIV,  # 1 top = st0 / st1
        0x07  =>  :MOD,  # 1 top = st0 % st1       
        
        0x08  =>  :AND,  # 1 top = st0 & st1
        0x09  =>  :OR,   # 1 top = st0 | st1
        0x0A  =>  :NOT,  # 1 top = ! st0
        0x0B  =>  :XOR,  # 1 top = st0 ^ st1
        0x0C  =>  :NOP,
        0x0D  =>  :NOP,
        0x0E  =>  :NOP,
        0x0F  =>  :NOP,
        
        0x10  => :POPV, 
        0x11  => :PSHV,
        
        0xF0  => :PRT,  # 2 print nb
        0xF1  => :PRTT, # 1 print top
        0xF2  => :PRTP, # 1 print top; pop
        
        0xFF  => :STOP
      }
  
    end
    
    ################## Workflow ##################################
    def step
      op = @opcodes[@byte_code[@ptr]]
      @ops[op].call
      @ptr += 1
    end
    
    def play(code)
      @byte_code = code
      step while !@STOP
    end
    
    def dbg(code, mem_slots = [])
      @byte_code = code
      while !@STOP do
        puts '---------------'
        puts "STACK: #{@stack}"
        puts "PTR: #{@ptr}"
        mem_slots.each do |slot|
          puts "MEM[#{slot}] = #{@MEM[slot]}"
        end
        
        op = @opcodes[@byte_code[@ptr]]
        puts ">> #{op.to_s} #{@byte_code[@ptr+1]} #{@byte_code[@ptr+2]}"
        @ops[op].call
        @ptr += 1
        gets
      end
    end
    
    ################## Auxilary methods ##########################
  
    def get_opcodes_reverted
      ops = {}
      @opcodes.each do |k, v|
          ops[v] = k unless ops[v]
      end   
      ops
    end
    
    def get_op_size(op)
      case op
        when :PSH, :POPV, :PSHV
          2
        else 1
      end
    end
    
    def has_addr?(op)
      [:POPV, :PSHV].include? op
    end
    
    def to_asm(code)
      ptr = 0
      t = get_opcodes_reverted
      while ptr < code.size
        op = @opcodes[ code[ptr] ]
        str = "#{ptr}: "
        str += op.to_s
        (get_op_size(op) - 1).times do
          ptr += 1
          str += " #{code[ptr]}"
          str += '(addr) ' if(has_addr?(op))
        end
        puts str
        ptr += 1
      end
    end
  
    ################## Core operations ##########################
  
    def nop
      #do nothig ;)
    end
    
    def stop
      @STOP = true
    end
  
    #Binary operations
    def add()
      push( pop + pop)
    end
  
    def sub()
      st0 = pop
      push( pop - st0 )
    end
  
    def mul()
      push( pop * pop)
    end
  
    def div()
      st0 = pop
      push( pop / st0 )
    end
  
    def mod()
      st0 = pop; push( pop % st0 )
    end
    
    #logical
    def o_and()
      st0 = pop
      st1 = pop
      if st0 != 0 && st1 != 0
        push 1
      else
        push 0
      end
    end
    
    def o_or()
      st0 = pop
      st1 = pop
      if st0 != 0 || st1 != 0
        push 1
      else
        push 0
      end
    end
    
    def o_not()
      st0 = pop
      push st0 != 0 ? 0 : 1
    end
    
    def popv  #pops to specified addr
      @MEM[next_byte] = pop
    end
    
    def pshv #pushes variable into stack
      push @MEM[next_byte]
    end
  
    #Stack
    def psh() #value
      value = next_byte
      push value
    end
  
    #pop is mentioned below
  
    #Printing a character
    def prt #value
      value = next_byte
      print value.chr.to_s
    end
    #prints top of stack
    def prtt 
      print pick.chr.to_s
    end
    #prints top of stack popping it
    def prtp
      print pop.chr.to_s
    end 
  
    private #####################################################
  
    def push(val)
      abort 'tinyVM PANIC: Stack overflow' if @stack.size == STACK_SIZE
      @stack.push( val )
      set_flags val
    end
  
    def pop()
      abort 'tinyVM PANIC: Trying to pop from empty stack' if @stack.empty?
    
      @stack.pop
    end
  
    def pick()
      abort 'tinyVM PANIC: Trying to pick from empty stack' if @stack.empty?
    
      @stack.last
    end
  
    def set_flags(val)
      @ZF = val == 0
      @LF = val < 0
      @RF = val >= BASE
    end
  
    def next_byte()
      @ptr += 1
      @byte_code[@ptr]
    end
  
  end

end
