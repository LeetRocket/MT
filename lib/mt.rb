require File.join(File.dirname(__FILE__) + '/MT', 'tiny_vm')
require File.join(File.dirname(__FILE__) , 'syntax_types')

def vm_test_1
  vm = MT::TinyVM.new

  pr = []
  codes = vm.get_opcodes_reverted

  pr.push codes[:PSH]
  pr.push 2

  pr.push codes[:PSH]
  pr.push 2

  pr.push codes[:ADD]

  pr.push codes[:PSH]
  pr.push '0'.ord

  pr.push codes[:ADD]
  pr.push codes[:PRTP]

  pr.push codes[:PRT]
  pr.push "\n".ord

  pr.push codes[:STOP]

  vm.play(pr)
end

T_RX = {
  :t_word   => /[a-zA-Z_][a-zA-Z0-9_]*/,
  :t_num    => /[0-9]+/,

  :t_obr    => /\(/,
  :t_cbr    => /\)/,

  :t_begin  => /\{/,    #unsupported
  :t_end    => /\}/,    #unsupported

  :t_scol   => /;/,
  :t_col    => /,/,     #unsupported

  :t_inc    => /\+\+/,  #unsupported
  :t_plus   => /\+/,

  :t_dec    => /\-\-/,  #unsupprted
  :t_minus  => /\-/,

  :t_mul    => /\*/,
  :t_div    => /\//,
  :t_mod    => /\%/,

  :t_eq     => /==/,
  :t_assign => /=/,
  :t_ne     => /!=/,
  :t_not    => /!/,
  :t_ge     => />=/,
  :t_gt     => />/,
  :t_le     => /<=/,
  :t_ls     => /</,
  :t_and    => /&&/,
  :t_or     => /\|\|/
}

KW_RX = {
  :t_void    =>  /^[vV][oO][iI][dD]$/,
  :t_typedef =>  /^[vV][aA][rR]$/,
  :t_if      => /^[iI][fF]$/,
  :t_else    => /^[eE][lL][sS][eE]$/,
  :t_while   => /^[wW][hH][iI][lL][eE]$/,
}

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
  :t_assign   => 0,
  :t_obr      => -1,
  :t_cbr      => -1,
  
}

def tokenize(str)

  tokenizer_src = ''
  T_RX.each do |k, v|
    tokenizer_src += '(?:' + v.source + ')|'
  end

  tokenizer = Regexp.new tokenizer_src.chop
  commenT_RX = /\/\/.*/

  found = str.gsub(commenT_RX, '').scan(tokenizer)
  tokens = []
  
  found.each do |token|
    T_RX.each do |k, v|
      if token =~ v then
        case k
          when :t_word then
            is_kw = false
            KW_RX.each do |kw, rx|
              if token =~ rx then
                tokens.push kw
                is_kw = true
                break
              end
            end
            tokens.push token unless is_kw
            break
          when :t_num then
            tokens.push token.to_i
            break
          else
            tokens.push k
            break
        end
      end
    end
  end
  tokens
end

def group(tokens)
  groups = []
  g = []
  tokens.each do |tkn|
    if tkn != :t_scol
      g.push tkn
    else
      groups.push g
      g = []
    end
  end
    abort("Semicolumn is missing") unless g.empty?
  groups
end

def postfix(statement)
  out = []
  stk = []
  prev = nil
  statement.each do |token|
    
    if token.kind_of? Numeric or token.kind_of? String
      out.push token
    
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
    puts "tkn: #{token}"
    puts "out: #{out.to_s}"
    puts "stk: #{stk.to_s}"
    puts "~~~~~~~~~~~"
    
  end
  
  out.push stk.pop while !stk.empty?
  out
end

test_str = "
    var i;
    i = 0;
    i = i + 1;
"

tokens = tokenize test_str
statements = group(tokens)

output = []

statements.each do |st|
  ctbl = MT::Computable.new st
  if ctbl.init_var?
    output.push ctbl.to_init_var
  else
    output.push ctbl
  end
end

code = []
output.each do |o|
  o.compile
  code += o.bin
end 

 code += [0xFF]  #STOP
 puts code.to_s
 puts '~~~~~~~~'
 vm = MT::TinyVM.new
 vm.to_asm code
 puts '~~~~~~~~'
 vm.dbg(code, [0,1, 2])





