require_relative 'db'

module WordNetPath
  #class Pointer < Treetop::Runtime::SyntaxNode
  module Pointer
    def self.space_to_camel(str)
      str.
      gsub(/ ([a-z])/) { |match| $1.upcase }.
      sub(/^[A-Z]/) { |match| $&.downcase }
    end

    def self.camel_to_space(str)
      str.
      gsub(/[A-Z]/) { |match| ' ' + $&.downcase }.
      sub(/^[a-z]/) { |match| $&.upcase }
    end

    def self.name_to_symbol(db, pointer_name)
      begin
	db.query("SELECT pointer_symbol FROM pointer_symbols WHERE pointer_name=?;", [pointer_name]) { |result_set|
	  result_set.next[0]
	}
      rescue
        raise "failed to find pointer symbol for pointer name '#{pointer_name}': #{$!} #{$@.join("\n")}"
      end
    end

    def self.name_to_predicate(db, pointer_name)
      "pointer_symbol='#{SQLite3::Database.quote(Pointer.name_to_symbol(db, pointer_name))}'"
    end

    # get the SQL expression to put in the WHERE clause in order to select
    # pointers that satisfy this relation from the pointers table
    def to_predicate(db)
      case text_value
	when 'meronym'
	  "pointer_symbol IN ('%m','%s','%p')"
	when 'holonym'
	  "pointer_symbol IN ('#m','#s','#p')"
	when 'domain'
	  "pointer_symbol IN (';c',';r',';d')"
	when 'domainMember'
	  "pointer_symbol IN ('-c','-r','-d')"
	when 'pertainsToNoun'
	  "pointer_symbol='\\' AND target_ss_type='n'"
	when 'derivedFromAdjective'
	  "pointer_symbol='\\' AND target_ss_type IN ('a','s')"
	when /Domain$/
	  Pointer.name_to_predicate(db, "Domain of synset - #{$`.upcase}")
	when /DomainMember$/
	  Pointer.name_to_predicate(db, "Member of this domain - #{$`.upcase}")
	else
	  Pointer.name_to_predicate(db, Pointer.camel_to_space(text_value))
      end
    end

    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      pointer_predicate = self.to_predicate(db)
      sql = <<-EOQ
        SELECT DISTINCT target_ss_type AS ss_type, target_synset_offset AS synset_offset
	FROM pointers
	WHERE #{pointer_predicate} AND
	      source_ss_type=? AND
	      source_synset_offset=?;
      EOQ
      db.synset2synset_query(sql, input, trace, text_value)
    end

    def efficient_conj?
      false
    end

    def reversible?
      (not %w{entailment cause participleOfVerb}.include?(text_value))
    end

    def reverse(db)
      case text_value
        when 'meronym'; 'holonym'
	when 'holonym'; 'meronym'
	
	when 'domain'; 'domainMember'
	when 'domainMember'; 'domain'
        
	when /Domain$/; $` + 'DomainMember'
	when /DomainMember$/; $` + 'Domain'
	else
	  sym = Pointer.name_to_symbol(db, Pointer.camel_to_space(text_value))
	  sql = <<-EOQ
	    SELECT pointer_name
	    FROM pointer_inverses
	    JOIN pointer_symbols
	      ON pointer_inverses.inverse=pointer_symbols.pointer_symbol
	    WHERE pointer_inverses.pointer_symbol=?;
	  EOQ
	  begin
	    db.query(sql, [sym]) { |result_set|
	      Pointer.space_to_camel(result_set.next[0])
	    }
	  rescue
	    raise "failed to find reverse of pointer #{text_value} (sym=#{sym.inspect}): #{$!}"
	  end
      end
    end
  end
  
  #class GlossRelation < Treetop::Runtime::SyntaxNode
  module GlossRelation
    def eval(db, input, indent, trace)
      $stderr.puts(indent + text_value) if (WordNetPath.debug?)
      new_indent = indent + ' '
      extra_select = ''
      extra_join = ''
      unless (elements[1].empty?)
        extra_select = ', gt1.start, gt1.end, gloss'
	extra_join = 'JOIN synsets ON synsets.synset_offset=gt1.synset_offset AND synsets.ss_type=gt1.ss_type'
      end
      sql =
	case elements[0].direction.text_value
	  when 'containedIn'
	    # return set of synsets whose glosses contain the input synsets
	    <<-EOQ
	      SELECT DISTINCT gt1.ss_type, gt1.synset_offset#{extra_select}
	      FROM senses
	      JOIN glosstags AS gt1 USING (sense_key)
	      #{extra_join}
	      WHERE senses.ss_type=? AND
		    senses.synset_offset=? AND
		    tag_type='sns'
	    EOQ
	  when 'Contains'
	    # return set of synsets contained in glosses of the input synsets
	    <<-EOQ
	      SELECT DISTINCT senses.ss_type, senses.synset_offset#{extra_select}
	      FROM glosstags AS gt1
	      JOIN senses USING (sense_key)
	      #{extra_join}
	      WHERE gt1.ss_type=? AND
		    gt1.synset_offset=? AND
		    tag_type='sns'
	    EOQ
	  else raise "WTF"
	end
      sql +=
        case elements[0].gloss_part.text_value
	  when /gloss/i
	    ';' # select from the whole gloss, no further restriction necessary
	  when /def|ex/i
	    # select from just definitions or examples
	    tag_type = $&.downcase
	    <<-EOQ
	      AND EXISTS (
	        SELECT *
		FROM glosstags AS gt2
		WHERE gt2.ss_type=gt1.ss_type AND
		      gt2.synset_offset=gt1.synset_offset AND
		      gt2.tag_type='#{tag_type}' AND
		      gt2.start <= gt1.start AND
		      gt2.end >= gt1.end
	      );
	    EOQ
	  else raise "WTF"
	end
      if (extra_select.empty?)
        db.synset2synset_query(sql, input, trace, text_value)
      else
	# FIXME this is mostly the same as synset2synset_query, except it does
	# some extra filtering with the context regexps. It would be nice to
	# fold the regexps into the SQL query, but I tried using
	# db.create_function('regexp', 2) {...}, and it segfaulted :(
	pre_re, post_re = *elements[1].context.to_regexps
	db.prepare(sql) { |stmt|
	  pb = (WordNetPath.debug? ? ProgressBar.new("query", input.size) : nil)
	  output = Set[]
	  input.each { |source_synset|
	    pb.inc if (WordNetPath.debug?)
	    o = nil
	    stmt.execute(*source_synset) { |result_set|
	      o =
		result_set.
		collect { |row| row.to_a }.
		select { |row|
		  start, finish, gloss = *row[2,3]
		  pre_str = gloss[0, start]
		  post_str = gloss[finish, gloss.length - finish]
		  pre_str =~ pre_re and post_str =~ post_re
		}.
		collect { |row| row[0,2] }.
		to_set
	    }
	    WordNetPath.add_to_trace(trace, source_synset, text_value, o)
	    output.merge(o)
	  }
	  pb.finish if (WordNetPath.debug?)
	  output
	}
      end
    end

    def efficient_conj?
      false
    end

    def reversible?
      true
    end

    def reverse(db)
      case elements[0].direction.text_value
	when 'containedIn'
	  elements[0].gloss_part.text_value.downcase + 'Contains'
	when 'Contains';
	  'containedIn' + elements[0].gloss_part.text_value.capitalize + 'Of'
	else raise "WTF"
      end +
      elements[1].text_value
    end
  end

  module RegexpExpr
    def to_regexps
      # blech, eval
      [
        eval("/#{pre.text_value}$/#{modifiers.text_value}"),
        eval("/^#{post.text_value}/#{modifiers.text_value}")
      ]
    end
  end
end
