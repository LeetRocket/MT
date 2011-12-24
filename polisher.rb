# Rever
# Nightly monkey-coded 2.30 - 5.30
# Time to sleep
class Polisher
  
  def self.solve(expr)
    @@dbg = true
    
    @@num_rx = /\d+\.?\d*/
    
    @@ob = 0
    @@cb = 1   
    @@ops = {
      '('  => @@ob,
      ')'  => @@cb,
      '+'  => 2,
      '-'  => 2,
      '*'  => 3,
      '/'  => 3, 
      '^' => 4
    }
    
    token_rx_proto = '(?:' + @@num_rx.source + ')'
    @@ops.keys.each do |k|
      token_rx_proto << '|(?:' + Regexp.escape(k) + ')'
    end
    @@token_rx = Regexp.new token_rx_proto
    post_tokens = self.translate(expr)
    
    self.compute(post_tokens)
  end
  
  def self.translate(inf)
    puts "=======\nTranslationg into postfix notation\n=======" if @@dbg
    post = []
    ops = []
    
    #okay, let's filter and not allow two ops in a row
    last_was_op = true
    
    inf_tokens = inf.scan @@token_rx
    inf_tokens.each do |tkn|
      puts "------\nCurrent token : #{tkn}" if @@dbg
      if tkn =~ @@num_rx
        
        unless last_was_op
          abort "Syntax error: two numerics in a row"
        end
        last_was_op = false
        
        num = 0
        if tkn =~ /\./
          num = tkn.to_f
        else
          num = tkn.to_i
        end
        post.push num
      
      else
        if @@ops[tkn] != @@ob && @@ops[tkn] != @@cb
          if last_was_op 
            abort "Syntax error: two ops in a row"
          end
          last_was_op = true 
        end        
        
        if ops.size == 0 || @@ops[tkn] == @@ob
          ops.push tkn
        
        elsif @@ops[tkn] == @@cb
          while ops.size != 0 && @@ops[ops.last] != @@ob do
            post.push ops.pop
          end
          if ops.size == 0
            abort "Syntax error: Opening bracket is missing"
          end  
          ops.pop
        
        else
          while ops.size != 0 && @@ops[ops.last] >= @@ops[tkn]  do
            post.push ops.pop
          end
          ops.push tkn
        end
      end
      puts "Output : #{post}" if @@dbg
      puts "Stack : #{ops}" if @@dbg
    end
    puts "-------\npopping the stack out" if @@dbg
    while ops.size != 0 do
      op = ops.pop
      if @@ops[op] == @@ob
        abort "Syntax error: Closing bracket is missing"
      end
      post.push op
    end
    puts "Output : #{post}" if @@dbg
    
    post
  end
  
  def self.compute(post_tokens)
    puts "=======\nComputing result\nExpression: #{post_tokens.join ' '}\n=======\n" if @@dbg
    stack = []
    post_tokens.each do |tkn|
      puts "Token applied: #{tkn}\n" if @@dbg
      if tkn.kind_of? Numeric
        stack.push tkn
      else
        abort( "Needed 2 nums found #{stack.size}") if stack.size < 2
        case tkn
          when '+'
            stack.push( stack.pop + stack.pop)
          when '-'
            a = stack.pop
            stack.push( stack.pop - a)
          when '*'
            stack.push( stack.pop * stack.pop)
          when '/'
            a = stack.pop
            stack.push( stack.pop / a.to_f)
          when '^'
            stack.push( stack.pop ** stack.pop)
        end
      end
      puts "Stack : #{stack}\n------" if @@dbg  
    end
    stack.last
  end

end

puts "please enter the string"
test_str = gets
Polisher.solve(test_str)

