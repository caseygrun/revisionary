js_files = revisionary.js core.js git.js
coffee_files = revisionary.coffee core.coffee git.coffee

.PHONY: all clean tests

all: revisionary.js core.js git.js

clean: 
	rm revisionary.js core.js git.js

revisionary.js: revisionary.coffee
	coffee -c revisionary.coffee

core.js: core.coffee
	coffee -c core.coffee

git.js: git.coffee 
	coffee -c git.coffee

tests: $(js_files) tests/test.coffee
	coffee -c tests/test.coffee
	qunit-cli tests/test.js 
