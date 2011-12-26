require File.join(File.dirname(__FILE__) + '/MT', 'tiny_vm')

module MT
  
  class Scope
    
    @@instances = []
    @@last_id = 0
    
    def Scope.compute_offsets
      offset = 0
      @@instances.each do |i|
        i.set_offset offset
        offset += i.size
        puts "#{i.id} SIZE = #{i.size}, OFFSET = #{i.offset}"
      end
    end
    
    attr_reader :parent
    
    def initialize(parent_scope)
      @vars = {}
      @funcs = {}
      @last_var_addr = 0
      @parent = parent_scope
      @@instances.push self
      @id = @@last_id
      @@last_id += 1
      puts 'Initialized new scope ' + @id.to_s + ' with parent ' + @parent.to_s
    end
    
    def contains_var?(var_name)
      if @vars.keys.include? var_name
        return true
      elsif @parent != nil 
        return @parent.contains_var? var_name
      end
      false
    end
  
    def reg_var(var_name)
      abort ("Redefinition of variable #{var_name}") if self.contains_var? var_name
      @vars[var_name] = @last_var_addr
      @last_var_addr += 1
    end
    
    def get_var_addr(var_name)
      abort("Variable #{var_name} is undefined") unless self.contains_var? var_name
      v = @vars[var_name]
      if v == nil
        return @parent.get_var_addr(var_name)
      end
      puts "SCOPE_#{@id}::#{var_name} = #{@offset + v}"
      @offset + v
    end
  
    def size()
      @vars.keys.size
    end
    
    def set_offset(offset)
      @offset = offset
    end
    
    def offset()
      @offset
    end
    
    def id
      @id
    end
  end
  
  class LazyAddress
    
    def initialize(scope, var_name)
      @scope = scope
      @var_name = var_name
    end
    
    def real_addr
      @scope.get_var_addr(@var_name)
    end
  
  end
  
  class LazyCall
    def initialize(func_name)
      @func_name = func_name
    end
    
    def real_addr
    
    end
  end
  
  class Compileable
    attr_reader :bin, :scope
  
    def initialize(scope)
      @is_compiled = false
      @bin = []
      @scope = scope
    end
    def compile()
      abort( "Compilation not implemented" )
    end
    def compiled?
      @is_compiled
    end
  
    private
  
    def get_codes
      vm = MT::TinyVM.new
      vm.get_opcodes_reverted
    end
  
  end
  
  class Block < Compileable
    
    @@compiled_everything = false
    
    def initialize(synths, parent_scope, is_global = false)
      scope = Scope.new parent_scope
      super(scope)
      puts "Block binded to Scope \##{@scope.id}"
      @synths = synths
      @to_compile = []
      @is_global = is_global
    end
    
    def compile()
      @synths.each do |st|
         ctbl = MT::Statement.new st, @scope
         if ctbl.rotten?
           abort("Rotten statement : #{st}")
         elsif ctbl.init_var?
           @to_compile.push ctbl.to_init_var
         elsif ctbl.if?
           @to_compile.push ctbl.to_if
         elsif ctbl.else?
           abort 'Unexpected else statement' unless @to_compile.last.kind_of? IfStatement
           @to_compile.last.set_else_block ctbl.to_else
         elsif ctbl.while?
            @to_compile.push ctbl.to_while
         elsif ctbl.func?
            ctbl.to_func  # Dont push it not to cause damage
         else
           @to_compile.push ctbl
         end
      end
      @to_compile.each do |c|
        puts "Compiling #{c.to_s}"
        c.compile
        @bin += c.bin
      end
      @bin = [0] if @bin.empty?
      if @is_global
        @bin = Func.encode + @bin
        puts "COMPUTING SCOPE OFFSETS"
        Scope.compute_offsets
        for i in 0...(@bin.size)
          if @bin[i].kind_of? LazyAddress
            @bin[i] = @bin[i].real_addr
          end
        end
        @bin << 0xFF # STOP
        @@compiled_everything = true
      end
      @is_compiled = true
      @bin
    end
    
    def size
      @bin.size
    end
    
  end

  class VarContainer < Compileable
    attr_reader :var_name
    def initialize(var_name, scope)
      super(scope)
      @var_name = var_name
    end
    def compile(var_addr)
      abort( "Not implemented" )
    end
  end

  class InitVar < VarContainer
    def compile()
      @scope.reg_var(@var_name)
      puts "Registered var #{@var_name} #{@scope.id})"
      @is_compiled = true
    end  
  end

  class GetVar < VarContainer
    def compile()
      c = get_codes
      @bin << c[:PSHV]
      @bin << LazyAddress.new(@scope, @var_name)
      @is_compiled = true
    end
  end

  class AssignVar < VarContainer
    def compile()
      c = get_codes
      @bin << c[:POPV]
      @bin << LazyAddress.new(@scope, @var_name)
      @is_compiled = true
    end
  end
  
  class IfStatement < Compileable
    def initialize(condition, true_block, false_block)
      super(true_block.scope)
      @condition = condition #Statement is expected
      @true_block = true_block
      @false_block = false_block #TODO: insert block when ready
    end
    
    def compile()
      c = get_codes
      @condition.compile
      @true_block.compile
      @false_block.compile
      
      @bin += @condition.bin
      @bin << c[:JPRZ]
      @bin << @true_block.bin.size + 3  # Jumping over true_block and jumper over false block
      @bin += @true_block.bin
      @bin << c[:JPR]
      @bin << @false_block.bin.size + 2 # Jumping over
      @bin += @false_block.bin
      @bin << c[:NOP]
      @bin << c[:NOP]
      @is_compiled = true
    end
    
    def set_else_block(block)
      @false_block = block
    end
    
  end
  
  class WhileStatement < Compileable
    def initialize(condition, block)
      super(block.scope)
      @condition = condition
      @block = block
    end
    
    def compile
      c = get_codes
      @condition.compile
      @block.compile
      
      @bin += @condition.bin
      @bin << c[:JPRZ]
      @bin << @block.size + 3
      @bin += @block.bin
      @bin << c[:JPR]
      @bin << -(2 + @block.bin.size + @condition.bin.size )
    end
  end
  
  class Func < Compileable
    
    ## Static part
    
    
    @@last_id = 0
    @@funcs = {}    #name -> function
    @@bin = {}    #name -> bin
    
    
    def self.reg(name, bin)
      @@funcs[name] = bin
    end
    
    def self.encode
      bin = [ 0x32, 0]  #jump somewhere
      
      @@funcs.values.each do |f|
        puts "FUNCS::: #{f}\n"
        f.compile unless f.compiled?
        bin += f.bin
      end
      bin[1] = bin.size
      bin
    end
    
    ## Static part ends
    attr_reader :name, :params, :block, :id  
    def initialize(name, params, block)
      super(block.scope)
      @name = name
      @params = params
      @block = block
      
      @@funcs[@name] = self
      @id = @@last_id
      @@last_id += 1
    end
    
    def pre_compile
      code = []
      @params.each do |p|
        InitVar.new(p, @block.scope).compile
        as = AssignVar.new(p, @block.scope)
        as.compile
        code += as.bin
      end
      code
    end
    
    def post_compile
      [0x40]  #RET
    end
    
    def set_offset(val)
      @offset = val
    end
    
    def offset
      @offset
    end
    
    def compile
      @bin += pre_compile
      @block.compile
      @bin += @block.bin
      @bin += post_compile
      @is_compiled = true
      @bin
    end
    
  end
  
  
  class FuncCall < Func
  end
  
  class Return < IfStatement
  end
  
  
  class Statement < Compileable
    PRTY = {
      :t_not      => 8,
      :t_mul      => 7,
      :t_div      => 7,
      :t_mod      => 7,
      :t_plus     => 6,
      :t_minus    => 6,
      :t_lt       => 5,
      :t_le       => 5,
      :t_gt       => 5,
      :t_ge       => 5,
      :t_ne       => 4,
      :t_eq       => 4,
      :t_and      => 3,
      :t_or       => 2,
      :t_col      => 0,
      :t_return   => -1,
      :t_obr      => -1,
      :t_cbr      => -1,
    }
  
    attr_reader :tokens
  
    def initialize(tokens, scope)
      super(scope)
      @postfix = false
      @compiled = false
      @tokens = tokens
    end
  
    def postfix? 
      @postfix
    end
  
    def postfix()
      var_assign = nil
      out = []
      stk = []
      prev = nil
      @tokens.each do |token|
        if token.kind_of? Numeric
          out.push token
        elsif token.kind_of? String
          out.push GetVar.new(token, @scope)
        elsif token == :t_assign
          var_name = out.pop.var_name
          var_assign = AssignVar.new var_name, @scope
        elsif token == :t_obr || stk.empty?
          stk.push token
        elsif token == :t_cbr
          while !stk.empty? && stk.last != :t_obr
            out.push stk.pop
          end
          abort("Missing opening bracket") if stk.empty?
          stk.pop

        elsif PRTY[token]
          while !stk.empty? && PRTY[stk.last] >= PRTY[token]
            out.push stk.pop
          end
          stk.push token

        else
          abort("Unknown symbol: #{token}")
        end
        prev = token
      end
      out.push stk.pop while !stk.empty?
      out.push var_assign if var_assign
      @postfix = true
      @tokens = out
    end  

    def init_var?
      @tokens.size >= 2 && @tokens[0] == :t_typedef && @tokens[1].kind_of?(String)
    end
  
    def to_init_var
      abort( "Unexpected token #{@tokens[2]} after declaration of variable" ) unless @tokens.size == 2
      InitVar.new( @tokens[1], @scope )
    end
    
    def has_blocks?
      @tokens.each do |t|
        return true if t.kind_of? Array
      end
      
      false
    end
    
    def if?
      @tokens.first == :t_if
    end
    
    def to_if
      abort("If statement: unexpected #{@tokens[ptr]} expected :t_obr") if @tokens[1] != :t_obr
      cond_stk = []
      ptr = 2
      while @tokens[ptr] != :t_cbr && ptr < @tokens.size
        cond_stk << @tokens[ptr]
        ptr += 1
      end
      abort("If statement: closing bracket is missing") if ptr == @tokens.size
      ptr += 1
      abort("If statement: true_block is missing") unless @tokens[ptr].kind_of? Array
      cond = Statement.new( cond_stk, @scope )
      block = Block.new @tokens[ptr], @scope
      
      return IfStatement.new(cond, block, Block.new([], @scope))
    end
       
    def else?
      @tokens.first == :t_else
    end
    
    def to_else
      abort("Else statement: expected :t_else and block; found: #{@tokens}") unless @tokens.size == 2
      abort("Else statement: expected block, found: #{@tokens[1]}") unless @tokens[1].kind_of? Array
      return Block.new(@tokens[1], @scope)
    end
    
    def while?
      @tokens.first == :t_while
    end
    
    def to_while
      abort("While statement: unexpected #{@tokens[ptr]} expected :t_obr") if @tokens[1] != :t_obr
      cond_stk = []
      ptr = 2
      while @tokens[ptr] != :t_cbr && ptr < @tokens.size
        cond_stk << @tokens[ptr]
        ptr += 1
      end
      abort("While statement: closing bracket is missing") if ptr == @tokens.size
      ptr += 1
      abort("While statement: true_block is missing") unless @tokens[ptr].kind_of? Array
      cond = Statement.new( cond_stk, @scope )
      block = Block.new @tokens[ptr], @scope
      
      return WhileStatement.new(cond, block)
    end
    
    def func?
      @tokens.size >= 3 && 
      @tokens[0] == :t_void || @tokens[0] == :t_typedef &&
      @tokens[1].kind_of?(String) &&
      @tokens[2] == :t_obr
    end
    
    def to_func
      type = @tokens[0]
      name = @tokens[1]
      params = []
      block = @tokens.last
      unless @tokens.last.kind_of? Array
        abort ("Expected to find block in end of function, found #{@tokens.last}") 
      end        
      ptr = 3
      while true
        if @tokens[ptr] == :t_typedef
          ptr += 1
          if @tokens[ptr].kind_of? String
            params.push @tokens[ptr]
            ptr += 1
            if @tokens[ptr] == :t_coma
              ptr += 1
            elsif @tokens[ptr] == :t_cbr
              break
            else
              abort('Unexpected end of function definition') unless @tokens[ptr]
              abort("Func definition : :t_coma or :t_cbr expected, #{@tokens[ptr]} found")
            end  
          else
            abort('Unexpected end of function definition') unless @tokens[ptr]
            abort("Func definition : param name expected, #{@tokens[ptr]} found")
          end
        elsif @tokens[ptr] == :t_cbr
          break
        else
          abort('Unexpected end of function definition') unless @tokens[ptr]
          abort("Func definition : :t_typedef expected, #{@tokens[ptr]} found")
        end
      end
      if type == :t_void
        return Func.new(name, params, Block.new(@tokens.last, nil) )
      else
        
      end
    end
    
    
    def rotten? #rotten means that statement pushes value to stack and there's no one to pop it
      !(if? || else? || while? || func?) &&
      !@tokens.include?(:t_assign) &&
      !@tokens.include?(:t_return) &&
      !@tokens.include?(:t_typedef)
    end
    
    
    #########################################
  
    def compile()
      c = get_codes
      postfix unless self.postfix?
      @tokens.each do |token|
        if token.kind_of? Numeric
          @bin.push c[:PSH]
          @bin.push token
        elsif token.kind_of?( GetVar ) || token.kind_of?( AssignVar )
          token.compile
          @bin += token.bin
          
        #Compliling operations
        elsif token == :t_plus
          @bin << c[:ADD]
        elsif token == :t_minus
          @bin << c[:SUB]
        elsif token == :t_mul
          @bin << c[:MUL]
        elsif token == :t_div
          @bin << c[:DIV]
        elsif token == :t_mod
          @bin << c[:MOD]
        elsif token == :t_and
          @bin << c[:AND]
        elsif token == :t_or
          @bin << c[:OR]
        elsif token == :t_not
          @bin << c[:NOT]
        elsif token == :t_eq
          @bin << c[:EQ]
        elsif token == :t_ne
          @bin << c[:NE]
        elsif token == :t_lt
          @bin << c[:LT]
        elsif token == :t_le
          @bin << c[:LE]
        elsif token == :t_gt
          @bin << c[:GT]
        elsif token == :t_ge
          @bin << c[:GE]
        elsif token == :t_return
          @bin << c[:RETV]
        else
          abort ("Unexpected token #{token}")
        end
      end
      @is_compiled = true
    end
  
  end

end