MODULE = WordNetPath
SRCS   = word_net_path.rb db.rb parser.treetop parser_en.treetop parser_es.treetop eval.rb eval_en.rb eval_es.rb
TESTS  = test_parser.rb test_eval.rb test_eval_es.rb

CONFIGDIR=trips/src/config
include $(CONFIGDIR)/ruby/lib.mk
include $(CONFIGDIR)/ruby/defs.mk

install::
	(cd trips/src/util/ && $(MAKE) install)

install-needed-gems:
	$(GEM) install sqlite3 --version '>=1.3.5'
	$(GEM) install treetop --version '>=1.4.10'
	$(GEM) install progressbar --version '>=0.10.0'

test: $(SRCS) $(TESTS)
	for t in $(TESTS) ; do \
	  echo ; \
	  echo $$t ; \
	  $(RUBY) $$t ; \
	done

# just in case this gets made by treetop somehow
clean::
	rm -f parser{,_en,_es}.rb

