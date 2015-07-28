require_relative 'eval'
WordNetPath::Language = 'en' unless (defined?(WordNetPath::Language))
require_relative 'eval_' + WordNetPath::Language
# doesn't work:
#require_relative 'parser'
Treetop.load File.dirname(__FILE__) + '/parser_' + WordNetPath::Language
Treetop.load File.dirname(__FILE__) + '/parser'

