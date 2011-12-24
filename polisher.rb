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
        puts "WTF?????? TWO NUMERICS IN A ROW" unless last_was_op
        last_was_op = false
        num = 0
        if tkn =~ /\./
          num = tkn.to_f
        else
          num = tkn.to_i
        end
        post.push num
      else
        puts "WTF?????? TWO OPS IN A ROW" if last_was_op
        last_was_op = true
        if ops.size == 0 || @@ops[tkn] == @@ob
          ops.push tkn
        elsif @@ops[tkn] == @@cb
          while ops.size != 0 && @@ops[ops.last] != @@ob do
            post.push ops.pop
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
      post.push ops.pop
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

Polisher.solve(test_str = '2 + 2 * 2 * (18 - 9) ^ 65')

