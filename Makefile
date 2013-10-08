js_files = store.js git.js
coffee_files = store.coffee git.coffee

.PHONY: all clean tests

all: store.js git.js

clean: 
	rm store.js git.js

store.js: store.coffee
	coffee -c store.coffee

git.js: git.coffee 
	coffee -c git.coffee

tests: $(js_files) tests/test.coffee
	coffee -c tests/test.coffee
	node tests/test.js
