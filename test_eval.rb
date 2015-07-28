require 'test/unit'
require_relative 'word_net_path'

WordNetPath.debug = false
module WordNetPath
  class TestEvaluation < Test::Unit::TestCase
    def setup
      @p = ExpressionParser.new
      @db = SQLite3::Database.new(ENV['TRIPS_BASE'] + '/etc/WordNetSQL/wn.db')
    end

    def assert_parses(str)
      tree = @p.parse(str)
      assert_not_nil(tree, @p.failure_reason)
      return tree
    end

    def assert_num_results(exp_num, str)
      tree = assert_parses(str)
      results = tree.eval(@db, Set[], '', {})
      assert_kind_of(Set, results)
      assert_equal(exp_num, results.size, "expected #{exp_num} results, but got #{results.size}, from #{str}")
      return results
    end

    def test_wolf_hyponym
      assert_num_results(5, "wolf%1:05:00:: hyponym")
    end

    def test_taxons
      tree = assert_parses("taxon%1:14:00:: hyponym*")
      results = tree.eval(@db)
      assert_kind_of(Set, results)
      assert_operator(29, :<, results.size)
    end
    
    def test_predicate
      assert_num_results(13, "coalition%1:14:00:: containedInGlossOf [!instanceHypernym]")
      assert_num_results(1, "sleep%1 hypernym [instanceHyponym]")
      assert_num_results(1, "sleep%1 hypernym [{,10} hyponym]")
    end

    def test_partial_sense_key_to_like_expr
      psk2le = Hash[*%w{
	sleep%1:26:00::	sleep\\%1:26:00:%:%
	sleep%		sleep\\%%
	take_out%:41	take\\_out\\%_:41:%
	%:18		%\\%_:18:%
      }]
      psk2le.each_pair { |psk, le|
        assert_equal(le, SenseKey.to_like_expr(psk))
      }
    end
    
    def test_partial_sense_keys
      key2count = {
	"sleep%1:26:00::" => 1,
	"sleep%1:26:00" => 1,
	"sleep%1" => 4,
	"sleep%" => 6,
	"take_out%:41" => 2
      }
      key2count.each_pair { |key, count|
        assert_num_results(count, key)
      }
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
      assert_reversible('hyponym', 'hypernym')
      assert_reversible('hyponym*', 'hypernym*')
      assert_reversible('hyponym meronym', 'holonym hypernym')
      assert_reversible(
        '(hyponym | meronym)* glossContains?',
	'containedInGlossOf? (hypernym | holonym)*'
      )
      assert_reversible('defContainsInContext:/a # regexp/i', 'containedInDefOfInContext:/a # regexp/i')
    end

    def test_not_reversible
      assert_not_reversible('entailment')
      assert_not_reversible('taxon%1:14:00::')
      assert_not_reversible('taxon%1:14:00:: hyponym*')
      assert_not_reversible('taxon%1:14:00:: | meronym')
      assert_not_reversible('hyponym entailment meronym')
    end

    def test_gloss_relations
      def_results = assert_num_results(1, "wolf%2:34:00:: defContains")
      ex_results = assert_num_results(1, "wolf%2:34:00:: exContains")
      gloss_results = assert_num_results(2, "wolf%2:34:00:: glossContains")
      assert_equal(gloss_results, def_results | ex_results)
    end

    def test_gloss_context
      assert_num_results(1, 'wolf%2:34:00:: glossContainsInContext:/eat #/')
      assert_num_results(1, 'wolf%2:34:00:: glossContainsInContext:/teenager # the pizza/i')
      results = assert_num_results(1, 'leak%2:32:01:: [ glossContainsInContext:/\bbe #/ & sharesWordsWith ]')
    end

    def test_shares_words_with
      results = assert_num_results(46, 'get_hold_of%2:35:00:: sharesWordsWith')
      assert_includes(results, ['v',2599636])
    end
  end
end

