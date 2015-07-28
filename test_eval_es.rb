require 'test/unit'
module WordNetPath
  Language = 'es'
end
require_relative 'word_net_path'

WordNetPath.debug = false
module WordNetPath
  class TestEvaluation < Test::Unit::TestCase
    def setup
      @p = ExpressionParser.new
      @db = SQLite3::Database.new(ENV['TRIPS_BASE'] + '/etc/WordNetSQL/eswn.db')
    end

    def assert_parses(str)
      tree = @p.parse(str)
      assert_not_nil(tree, @p.failure_reason)
      return tree
    end

    def assert_num_results(exp_num, str)
      tree = assert_parses(str)
      results = tree.eval(@db)
      assert_kind_of(Set, results)
      assert_equal(exp_num, results.size, "expected #{exp_num} results, but got #{results.size}, from #{str}")
      return results
    end

    def test_gobierno_hyponym
      assert_num_results(3, "gobierno%1:00:02:: has_hyponym+")
    end

    def assert_reversible(exp_expr, exp_r_expr)
      tree = assert_parses(exp_expr)
      assert(tree.reversible?, "expected #{exp_expr} to be reversible, but it wasn't")
      act_r_expr = tree.reverse(@db)
      assert_equal(exp_r_expr, act_r_expr)
      r_tree = assert_parses(act_r_expr)
      assert(r_tree.reversible?, "expected #{act_r_expr} to be reversible, but it wasn't")
      act_expr = r_tree.reverse(@db)
      assert_equal(exp_expr, act_expr)
    end

    def assert_not_reversible(expr)
      tree = assert_parses(expr)
      assert((not tree.reversible?), "expected #{expr} not to be reversible, but it was")
    end

    def test_reversible
      assert_reversible('has_hyponym', 'has_hyperonym')
      assert_reversible('has_hyponym has_mero_any', 'has_holo_any has_hyperonym')
    end

    def test_not_reversible
      assert_not_reversible('see_also_wn15')
    end
  end
end

