require File.join(File.dirname(__FILE__), 'syntax_types')

tkns = [:t_return, 2, :t_plus, 2, :t_plus, 'a', :t_obr, :t_cbr]

sc = MT::Scope.new nil
st = MT::Statement.new tkns, sc
puts st.tokens.to_s
st.postfix
puts st.tokens.to_s
