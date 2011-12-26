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

  :t_begin  => /\{/,    
  :t_end    => /\}/,    

  :t_scol   => /;/,
  :t_coma    => /,/,     #unsupported
  
  :t_plus_assign  => /\+=/,
  :t_minus_assign => /\-=/,
  :t_mul_assign   => /\*=/,
  :t_div_assign   => /\/=/,
  :t_mod_assign   => /\%=/,
   
  :t_plus   => /\+/,
  :t_minus  => /\-/,

  :t_mul    => /\*/,
  :t_div    => /\//,
  :t_mod    => /\%/,
  
  :t_ge     => />=/,
  :t_gt     => />/,
  :t_le     => /<=/,
  :t_lt     => /</,
  :t_eq     => /==/,
  :t_ne     => /!=/,
  :t_not    => /!/,
  :t_assign => /=/,
  :t_and    => /&&/,
  :t_or     => /\|\|/
}

KW_RX = {
  :t_void    =>  /^[vV][oO][iI][dD]$/,
  :t_typedef =>  /^[vV][aA][rR]$/,
  :t_if      => /^[iI][fF]$/,
  :t_else    => /^[eE][lL][sS][eE]$/,
  :t_while   => /^[wW][hH][iI][lL][eE]$/,
  :t_return  => /^[rR][eE][tT][uU][rR][nN]$/
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
  :t_coma     => 0,
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
            # dirth to allow 'var i = 1;' ('var i =   =>  var i ; i =)
            if (
                 tokens.size >= 2 && 
                 k == :t_assign &&
                 tokens.last.kind_of?(String) && 
                 tokens[tokens.size - 2] == :t_typedef
               )
              var_name = tokens.last
              tokens.push :t_scol
              tokens.push var_name
            # dirth to enable += -= *= /= %=
            elsif (tokens.size >= 1 &&
                   [:t_plus_assign, 
                    :t_minus_assign,
                    :t_mul_assign,
                    :t_div_assign,
                    :t_mod_assign].include?( k ))
              var_name = tokens.last
              tokens.push :t_assign
              tokens.push var_name
              tokens.push case k
                when :t_plus_assign
                  :t_plus
                when :t_minus_assign
                  :t_minus
                when :t_mul_assign
                  :t_mul
                when :t_div_assign
                  :t_div
                when :t_tmod_assign
                  :t_mod
              end
              
            end
            tokens.push k unless [:t_plus_assign, :t_minus_assign, :t_mul_assign, :t_div_assign, :t_mod_assign].include? k
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
  ptr = 0
  nesting = 0
  block_extracting = false
  block_start_index = 0
  block_end_index = 0
  while ptr < tokens.size
    tkn = tokens[ptr]
    #extracting block
    if tkn == :t_begin
      g.push tkn
      unless block_extracting
        block_extracting = true
        block_start_index = g.size  
      else
        nesting += 1
      end
    elsif tkn == :t_end
      g.push tkn
      if nesting == 0
        abort('{ is missing') if !block_extracting
        block_extracting == false
        block_end_index = g.size - 1
        block = group g.slice(block_start_index, block_end_index - block_start_index)
        g = g.slice(0, block_start_index - 1) + [block]
        groups.push g
        g = []
        block_extracting = false
      else
        nesting -= 1
      end     
    elsif tkn != :t_scol
      g.push tkn
    elsif tkn == :t_scol
      if block_extracting
        g.push tkn
      else
        groups.push g
        g = []
      end
    end
    ptr += 1
  end
    unless g.empty?
      abort("; or } is missing") 
    end
  groups
end

fib = "
  //fibbonachi exposes if and while loops
  var prev = 0;
  var cur = 0;
  var counter = 0;
  while(counter < 10)
  {
    if(prev == 0 && cur == 0){
      var def_prev_val = 1;
      var def_cur_val = 1;
      prev = def_prev_val;
      cur = def_cur_val;
    }else{
      var tmp = cur;
      cur = cur + prev;
      prev = tmp;
      counter = counter + 1;
    }
  }
"

funcdef = "
  var result = 1;
  var n = 5;
  while ( n != 1{
    result *= n;
    n = n - 1;
  }
"

test_str = funcdef

def pretty(arr, ind=0)
  (ind).times{ print ' ' }
  puts '['
  arr.each do |e|
    if e.kind_of? Array
      pretty(e, ind+4)
    else
      (ind+4).times{ print ' ' }
      puts e.to_s
    end  
  end
  (ind).times{ print ' ' }
  puts ']'
end

puts test_str

puts "~~~~~~~~~~\nTokenized as\n~~~~~~~~~~~"
tokens = tokenize test_str
puts tokens.to_s

puts "~~~~~~~~~~\nGrouped as\n~~~~~~~~~~~"
statements = group(tokens)
pretty(statements)
 
puts "~~~~~~~~~~\nCompilation\n~~~~~~~~~~~"
b = MT::Block.new statements, nil, true
b.compile

puts "~~~~~~~~~~\nVM ASM:\n~~~~~~~~~~~"
vm = MT::TinyVM.new
vm.to_asm(b.bin)
puts '~~~~~~~~~~~~~'
vm.play b.bin, (0..3).to_a







