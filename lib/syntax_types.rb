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
      @last_var_addr = 0
      @parent = parent_scope
      @@instances.push self
      @id = @@last_id
      @@last_id += 1
      puts 'Initialized new scope ' + @id.to_s
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
      return v if v
      @parent.get_var_addr(var_name)
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
    
    def initialize(scope, scope_addr)
      @scope = scope
      @scope_addr = scope_addr
    end
    
    def real_addr
      offset = @scope.offset  
      offset + @scope_addr
    end
  
  end
  
  class Compileable
    attr_reader :bin
  
    def initialize(scope)
      @is_compiled = false
      @bin = []
      @scope = scope
    end
    def compile()
      abort( "Not implemented" )
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
    
    def initialize(synths, parent_scope)
      scope = Scope.new parent_scope
      super(scope)
      puts "Block binded to Scope \##{@scope.id}"
      @synths = synths
      @to_compile = []
    end
    
    def compile()
      prev = nil
      @synths.each do |st|
         ctbl = MT::Computable.new st, @scope
         if ctbl.init_var?
           @to_compile.push ctbl.to_init_var
         elsif ctbl.if_statement?
           @to_compile.push ctbl.to_if_statement
         else
           @to_compile.push ctbl
         end
         prev = st
      end
      @to_compile.each do |c|
        c.compile
        @bin += c.bin
      end
      unless @scope.parent
        puts "COMPUTING SCOPE OFFSETS"
        Scope.compute_offsets
        for i in 0...(@bin.size)
          if @bin[i].kind_of? LazyAddress
            @bin[i] = @bin[i].real_addr
          end
        end
      end
      
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
      puts "Registered var #{@var_name} #{@scope.id}\#(#{@scope.get_var_addr @var_name})"
      @is_compiled = true
    end  
  end

  class GetVar < VarContainer
    def compile(var_addr)
      c = get_codes
      @bin << c[:PSHV]
      @bin << LazyAddress.new(@scope, var_addr)
      @is_compiled = true
    end
  end

  class AssignVar < VarContainer
    def compile(var_addr)
      c = get_codes
      @bin << c[:POPV]
      @bin << LazyAddress.new(@scope, var_addr)
      @is_compiled = true
    end
  end
  
  class IfStatement < Compileable
    def initialize(condition, true_block, false_block)
      @condition = condition #Computable is expected
      @true_block = true_block
      @false_block = [] #TODO: insert block when ready
    end
    
    def compile()
      # TODO:write compilation for if block
      @bin = [0, 0]
      @true_block.compile
      @bin += @true_block.bin
      @is_compiled = true
    end
    
  end
  
  class Computable < Compileable
    PRTY = {
      :t_inc      => 9,
      :t_dec      => 9,
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
      abort( "Unexpected token #{@tokens[2]} after assigning a variable" ) unless @tokens.size == 2
      InitVar.new( @tokens[1], @scope )
    end
    
    def has_blocks?
      @tokens.each do |t|
        return true if t.kind_of? Array
      end
      
      false
    end
    
    def if_statement?
      @tokens.first == :t_if
    end
    
    def to_if_statement
      cond_stk = []
      ptr = 1
      abort("If statement: unexpected #{@tokens[ptr]}") if @tokens[ptr] != :t_obr
      while @tokens[ptr] != :t_cbr && ptr < @tokens.size
        cond_stk << @tokens[ptr]
        ptr += 1
      end
      abort("If statement: closing bracket is missing") if ptr == @tokens.size
      ptr += 1
      abort("If statement: true_block is missing") unless @tokens[ptr].kind_of? Array
      cond = Computable.new( cond_stk, @scope )
      block = Block.new @tokens[ptr], @scope
      
      return IfStatement.new(cond, block, [])
    end
    
    ########## TO IMPLEMENT #################
    
    def else_statement?
      abort('TO IMPLEMENT')
    end
    
    def to_else_statement
      abort('TO IMPLEMENT')
    end
    
    def while_statement?
      abort('TO IMPLEMENT')
    end
    
    def to_while_statement
      abort('TO IMPLEMENT')
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
          token.compile @scope.get_var_addr(token.var_name)
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
          
        else
          abort ("Unexpected token #{token}")
        end
      end
      @is_compiled = true
    end
  
  end

end