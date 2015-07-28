if (JRUBY_VERSION.nil? rescue true)
  require 'sqlite3'
else
  $: << ENV['TRIPS_BASE'] + '/etc/util'
  require 'java_sqlite3'
end
require 'progressbar'

class SQLite3::Database
  def synset2synset_query(sql, input, trace, step_name)
    prepare(sql) { |stmt|
      pb = (WordNetPath.debug? ? ProgressBar.new("query", input.size) : nil)
      output = Set[]
      input.each { |source_synset|
        pb.inc if (WordNetPath.debug?)
	o = nil
	stmt.execute(*source_synset) { |result_set|
	  o = result_set.collect { |row| row.to_a }.to_set
	}
	WordNetPath.add_to_trace(trace, source_synset, step_name, o)
	output.merge(o)
      }
      pb.finish if (WordNetPath.debug?)
      output
    }
  end
end
