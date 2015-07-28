require_relative 'db'

module WordNetPath
  #class Pointer < Treetop::Runtime::SyntaxNode
  module Pointer
    # get the SQL expression to put in the WHERE clause in order to select
    # pointers that satisfy this relation from the pointers table
    def to_predicate(db)
      if (text_value =~ /_any$/)
	"pointer_symbol LIKE '#{$`}%'"
      else
	"pointer_symbol = '#{text_value}'"
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
      text_value != 'see_also_wn15'
    end

    def reverse(db)
      case text_value
        when 'has_mero_any'; 'has_holo_any'
	when 'has_holo_any'; 'has_mero_any'
	
	when 'role_any'; 'involved_any'
	when 'involved_any'; 'role_any'
        
	else
	  sql = <<-EOQ
	    SELECT inverse
	    FROM pointer_inverses
	    WHERE pointer_inverses.pointer_symbol=?;
	  EOQ
	  begin
	    db.query(sql, [text_value]) { |result_set|
	      result_set.next[0]
	    }
	  rescue
	    raise "failed to find reverse of pointer #{text_value}: #{$!}"
	  end
      end
    end
  end
end
