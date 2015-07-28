require 'set'
require 'rubygems'
require 'treetop'
require 'forwardable'
require_relative 'db'

module WordNetPath
  def self.debug=(d)
    @debug = d
  end

  def self.debug?
    @debug
  end

  def self.with_debug(new_debug)
    old_debug = @debug
    begin
      @debug = new_debug
      yield
    ensure
      @debug = old_debug
    end
  end

  self.debug=true

  def self.add_to_trace(trace, source_synset, step_name, target_synset)
    return if (trace.nil?)
    if (Array === target_synset and target_synset[0] =~ /^[nvars]$/)
      trace[target_synset] ||=
	if (source_synset.nil?)
	  [step_name]
	else
	  trace[source_synset] + [step_name, target_synset]
	end
    else
      target_synset.each { |ts|
        add_to_trace(trace, source_synset, step_name, ts)
      }
    end
  end

  class Expr < Treetop::Runtime::SyntaxNode
    # set trace to a Hash to have it filled with a list of alternating source
    # synset and step name for each target synset
    def eval(db, input=Set[], indent='', trace=nil)
      db.results_as_hash = false
      db.type_translation = true
      diff.eval(db, input, indent, trace)
    end
    extend Forwardable
    def_delegators :diff,
      # can we call the efficient_conj method?
      :efficient_conj?,
      # efficiently filter outputs as part of a Conj, without DB or trace
      # TODO also use this in Diff and Pred?
      :efficient_conj,
      # can we get the reverse expression from this?
      :reversible?,
      # get a string that parses to the reverse expression, i.e. the one that
      # maps this expression's output to its input in all cases (I could have
      # called this "inverse", but I didn't want to confuse the relational
      # sense with the set theory sense)
      :reverse
  end

  module Infix
    include Enumerable
    def each
      yield head
      tail.elements.each { |te|
        yield te.elements[-1]
      }
    end

    def size
      1 + tail.elements.size
    end

    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      collect { |operand| operand.eval(db, input, new_indent, trace) }.inject(operator)
    end

    def efficient_conj?
      tail.elements.empty? and head.efficient_conj?
    end

    def efficient_conj(output_so_far)
      head.efficient_conj(output_so_far)
    end

    def reversible?
      all? { |operand| operand.reversible? }
    end

    def reverse(db)
      collect { |operand| operand.reverse(db) }.join(" #{self.operator} ")
    end
  end

  class Diff < Treetop::Runtime::SyntaxNode
    include Infix
    def operator; :-; end
  end
  class Disj < Treetop::Runtime::SyntaxNode
    include Infix
    def operator; :|; end
    
    # faster version for the large disjunctions resulting from loading files;
    # avoids duplicating a lot of small Set objects
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      result = Set[]
      each { |operand| result.merge(operand.eval(db, input, new_indent, trace)) }
      return result
    end

    def efficient_conj?
      all? { |operand| operand.efficient_conj? }
    end

    def efficient_conj(output_so_far)
      output = Set[]
      each { |operand| output.merge(operand.efficient_conj(output_so_far)) }
      return output
    end
  end
  class Conj < Treetop::Runtime::SyntaxNode
    include Infix
    def operator; :&; end
    
    # detect simple %# operands (and disjunctions thereof) and implement them
    # by filtering on ss_type instead of sense key matching, for efficiency
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      # do all the complex operands and collect the simple ones
      simple_operands = []
      output =
        collect { |operand|
	  if (operand.efficient_conj?)
	    simple_operands << operand
	    nil
	  else
	    operand.eval(db, input, new_indent, trace)
	  end
	}.
	reject { |o| o.nil? }.
	inject(operator)
      simple_operands.each { |operand|
        output = operand.efficient_conj(output)
      }
      output
    end
  end

  class Seq < Treetop::Runtime::SyntaxNode
    include Infix
    
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      so_far = input
      each { |operand|
        so_far = operand.eval(db, so_far, new_indent, trace)
      }
      return so_far
    end

    def reverse(db)
      collect { |operand| operand.reverse(db) }.reverse.join(' ')
    end
  end

  class Pred < Treetop::Runtime::SyntaxNode
    def min
      if (Count === count)
	count.min
      elsif (count.text_value == '!')
        0
      else
	1
      end
    end

    def max
      if (Count === count)
	count.max
      elsif (count.text_value == '!')
        0
      else
	(1.0/0.0)
      end
    end

    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      size_range = min..max
      WordNetPath.with_debug(false) {
	input.select { |ss|
	  size_range.include?(diff.eval(db, Set[ss], indent, nil).size)
	}.to_set
      }
    end

    def efficient_conj?
      false
    end

    def reversible?
      false
    end
  end

  class Rep < Treetop::Runtime::SyntaxNode
    def count?
      defined?(elements[1].count)
    end

    def count
      elements[1].count
    end

    def eval(db, input, indent, trace)
      if (count?)
	$stderr.puts(indent + text_value) if (WordNetPath.debug?)
	new_indent = indent + ' '
	so_far = input
	count.min.times { |i|
	  so_far = atom.eval(db, so_far, indent, trace)
	}
	i = count.min
	additional = nil
	while (i < count.max and (additional.nil? or not additional.empty?))
	  i += 1
	  if (additional.nil?)
	    #$stderr.puts "additional is nil" if (WordNetPath.debug?)
	    additional = so_far
	  else
	    so_far |= additional
	  end
	  additional = atom.eval(db, additional, indent, trace) - so_far
	  #$stderr.puts "additional.size = #{additional.size}" if (WordNetPath.debug?)
	end
	so_far | (additional || Set[])
      else
	#$stderr.puts "no rep" if (WordNetPath.debug?)
	atom.eval(db, input, indent, trace)
      end
    end

    def efficient_conj?
      (not count?) and atom.efficient_conj?
    end

    def efficient_conj(output_so_far)
      atom.efficient_conj(output_so_far)
    end

    def reversible?
      atom.reversible?
    end

    def reverse(db)
      atom.reverse(db) + (count? ? count.text_value : '')
    end
  end

  #class Count < Treetop::Runtime::SyntaxNode
  module Count
    def min
      case text_value
        when '?', '*'; 0
	when '+'; 1
	when /^\{\s*,/; 0
	when /^\{\s*(\d+)/; $1.to_i
	else raise "Invalid count text_value: #{text_value.inspect}"
      end
    end

    def max
      case text_value
        when '?'; 1
	when '*', '+'; (1.0/0.0)
	when /,\s*\}$/; (1.0/0.0)
	when /(\d+)\s*\}$/; $1.to_i
	else raise "Invalid count text_value: #{text_value.inspect}"
      end
    end
  end
  
  class Parens < Treetop::Runtime::SyntaxNode
    def reverse(db)
      '(' + expr.reverse(db) + ')'
    end

    extend Forwardable
    def_delegators :expr, :eval, :efficient_conj?, :efficient_conj, :reversible?
  end

  module SharesWordsWithExpr
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      sql = <<-EOQ
	SELECT DISTINCT s2.ss_type, s2.synset_offset
	FROM senses AS s1
	JOIN senses AS s2 USING (lemma)
	WHERE s1.ss_type=? AND s1.synset_offset=?;
      EOQ
      db.synset2synset_query(sql, input, trace, text_value)
    end

    def efficient_conj?
      false
    end

    def reversible?
      true
    end

    def reverse(db)
      'sharesWordsWith'
    end
  end

  class SenseKey < Treetop::Runtime::SyntaxNode
    def sense_key_to_synset_query(db, sql, arg, trace)
      output = db.query(sql, [arg]) { |result_set|
	result_set.collect { |row| row.to_a }.to_set
      }
      WordNetPath.add_to_trace(trace, nil, text_value, output)
      return output
    end

    # convert a partial sense key to an SQL LIKE expression escaped with backslash
    def self.to_like_expr(psk)
      le = psk.
	gsub(/[%_]/, "\\\\\\0"). # escape literal % and _
	sub(/^(?=\\%)/, '%'). # unspecified lemma
	sub(/(?<=%)(?=:)/, '_'). # unspecified ss_type
	gsub(/(?<=:)(?=:)/, '%') # unspecified other field
      if (le =~ /[%:]$/)
	le += '%'
      elsif (le.count(':') < 4)
        le += ':%'
      end
      return le
    end

    def eval(db, input, indent, trace)
      # NOTE: input ignored
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      if (text_value =~ /.%.:.{2}:.{2}:.*?:/) # could be a full sense key
	# try an exact match (faster than relying on LIKE)
	sql = <<-EOQ
	  SELECT ss_type, synset_offset
	  FROM senses
	  WHERE sense_key=?;
	EOQ
	output = sense_key_to_synset_query(db, sql, text_value, trace)
	return output unless (output.empty?)
      end
      sql = <<-EOQ
	SELECT ss_type, synset_offset
	FROM senses
	WHERE sense_key LIKE ? ESCAPE '\\';
      EOQ
      like_expr = SenseKey.to_like_expr(text_value)
      return sense_key_to_synset_query(db, sql, like_expr, trace)
    end

    def efficient_conj?
      text_value =~ /^%\d$/
    end

    def efficient_conj(output_so_far)
      ss_type_number = text_value[1].to_i
      ss_type_letter = ' nvars'[ss_type_number]
      output_so_far.reject { |ss| ss[0] != ss_type_letter }
    end

    def reversible?
      false
    end
  end

  class SynsetExpr < Treetop::Runtime::SyntaxNode
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      # NOTE: input ignored
      ss = [ss_type, synset_offset.to_i]
      WordNetPath.add_to_trace(trace, nil, text_value, ss)
      return Set[ss]
    end

    def efficient_conj?
      false
    end

    def reversible?
      false
    end
  end
  
  class FileExpr < Treetop::Runtime::SyntaxNode
    def eval(db, input, indent, trace)
      filename = string.to_s
      @@file2value ||= {}
      output = (@@file2value[filename] ||= # only load the file once
        begin
	  # load the lines of the file into an alternation expression as
	  # (partial) synset expressions, and evaluate it
	  expr =
	    File.open(filename, 'r').readlines.collect { |line|
	      line.
	      strip.
	      gsub(/\s+/,'_').
	      sub(/^[^%]+$/,'\0%') # add a % at the end if there's no % anywhere
	    }.join(' | ')
	  parser = ExpressionParser.new
	  tree = parser.parse(expr)
	  raise "Failed to parse expression from file #{filename}: #{parser.failure_reason}" if (tree.nil?)
	  WordNetPath.with_debug(false) { tree.eval(db) }
	end)
      WordNetPath.add_to_trace(trace, nil, text_value, output)
      return output
    end

    def efficient_conj?
      false
    end

    def reversible?
      false
    end
  end
  
  class StringExpr < Treetop::Runtime::SyntaxNode
    def to_s
      text_value.
      gsub(/(?:^"|"$)/,'').
      gsub(/\\[nrt]/) { |match| eval("\"#{$&}\"") }.
      gsub(/\\(.)/,'\1')
    end
  end
end

