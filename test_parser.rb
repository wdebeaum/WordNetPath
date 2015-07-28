require 'test/unit'
require_relative 'word_net_path'

module WordNetPath
  class TestParsing < Test::Unit::TestCase
    def setup
      @p = ExpressionParser.new
    end

    def assert_parses(str)
      tree = @p.parse(str)
      assert_not_nil(tree, @p.failure_reason)
      return tree
    end

    def test_expression
      # these are from the original email that inspired this code
      assert_parses("(hyponym | instanceHyponym | meronym)* containedInGlossOf?")
      assert_parses("(hyponym | instanceHyponym)* substanceMeronym? containedInGlossOf?")
      assert_parses("(hyponym | instanceHyponym)* substanceMeronym? (glossContains | containedInGlossOf)?")
      assert_parses("taxon%1:14:00:: hyponym* memberMeronym?")
    end

    def test_predicate
      assert_parses("hyponym meronym? containedInGlossOf? [!instanceHypernym]")
      assert_parses("hyponym meronym? [containedInGlossOf]")
      assert_parses("hypernym [{,10} hyponym]")
    end

    def test_partial_sense_keys
      assert_parses("sleep%1:26:00::")
      assert_parses("sleep%1:26:00")
      assert_parses("sleep%1")
      assert_parses("sleep%")
      assert_parses("take_out%:41")
      assert_parses("%:18")
    end

    def test_contained_in_context
      assert_parses("defContainsInContext:/cause to #/")
      assert_parses("containedInGlossOfInContext:/some\\s+cr[Aa]zy\\/\#{}regexp$/im")
    end
  end
end

