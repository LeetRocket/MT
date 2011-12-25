require File.join(File.dirname(__FILE__) + '/MT', 'tiny_vm')

module MT

  class Scope
  
    def initialize()
      @vars = {}
      @last_var_addr = 0
    end
  
    def contains_var?(var_name)
      @vars.keys.include? var_name
    end
  
    def reg_var(var_name)
      abort ("Redefinition of variable #{var_name}") if self.contains_var? var_name
      @vars[var_name] = @last_var_addr
      @last_var_addr += 1
    end
  
    def get_var_addr(var_name)
      #TODO implement lookup in parent scopes
      abort("Variable #{var_name} is undefined") unless self.contains_var? var_name
      @vars[var_name]
    end
  
    def size()
      @vars.keys.size
    end
  
  end

  GLOBAL_SCOPE = Scope.new
  
  class Compileable
    attr_reader :bin
  
    def initialize()
      @is_compiled = false
      @bin = []
    end
    def compile()
      abort( "Not implemented" )
    end
    def is_compiled?
      @is_compiled
    end
  
    private
  
    def get_codes
      vm = MT::TinyVM.new
      vm.get_opcodes_reverted
    end
  
  end

  class VarContainer < Compileable
    attr_reader :var_name
    def initialize(var_name)
      super()
      @var_name = var_name
    end
    def compile(var_addr)
      abort( "Not implemented" )
    end
  end

  class InitVar < VarContainer
    def compile()
      GLOBAL_SCOPE.reg_var(@var_name)
      puts "Registered var #{@var_name} (#{GLOBAL_SCOPE.get_var_addr @var_name})"
      @is_compiled = true
    end  
  end

  class GetVar < VarContainer
    def compile(var_addr)
      c = get_codes
      @bin << c[:PSHV]
      @bin << var_addr
      @is_compiled = true
    end
  end

  class AssignVar < VarContainer
    def compile(var_addr)
      c = get_codes
      @bin << c[:POPV]
      @bin << var_addr
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
  
    def initialize(tokens)
      super()
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
          out.push GetVar.new(token)
        elsif token == :t_assign
          var_name = out.pop.var_name
          var_assign = AssignVar.new var_name
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
      InitVar.new @tokens[1]
    end
  
    def compile()
      c = get_codes
      postfix unless self.postfix?
      @tokens.each do |token|
        if token.kind_of? Numeric
          @bin.push c[:PSH]
          @bin.push token
        elsif token.kind_of?( GetVar ) || token.kind_of?( AssignVar )
          token.compile GLOBAL_SCOPE.get_var_addr(token.var_name)
          @bin += token.bin
          
        #Compliling common operations
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
        else
          abort ("Unexpected token #{token}")
        end
      end
      @is_compiled = true
    end
  
  end

end