-RELEASE_DIR := out/release/
-COVERAGE_DIR := out/test/
-RELEASE_COPY := lib
-COVERAGE_COPY := lib tests


-BIN_MOCHA := ./node_modules/.bin/mocha
-BIN_JSCOVER := ./node_modules/.bin/jscover
-BIN_COFFEE := ./node_modules/coffee-script/bin/coffee

-TESTS := $(shell find tests -type f -name test-*)

-COFFEE_LIB := $(shell find lib -type f -name '*.coffee')
-COFFEE_TEST := $(shell find tests -type f -name 'test-*.coffee')

-COFFEE_RELEASE := $(addprefix $(-RELEASE_DIR),$(-COFFEE_LIB) )

-COFFEE_COVERAGE := $(-COFFEE_LIB)
-COFFEE_COVERAGE += $(-COFFEE_TEST)
-COFFEE_COVERAGE := $(addprefix $(-COVERAGE_DIR),$(-COFFEE_COVERAGE) )

-COVERAGE_FILE := coverage.html
-COVERAGE_TESTS := $(addprefix $(-COVERAGE_DIR),$(-TESTS))
-COVERAGE_TESTS := $(-COVERAGE_TESTS:.coffee=.js)

default: dev


dev: clean
	@$(-BIN_MOCHA) \
		--colors \
		--compilers coffee:coffee-script \
		--reporter list \
		--growl \
		$(-TESTS)

test: clean
	@$(-BIN_MOCHA) \
		--compilers coffee:coffee-script \
		--reporter tap \
		$(-TESTS)

release: dev
	@echo 'copy files'
	@mkdir -p $(-RELEASE_DIR)
	@cp -r $(-RELEASE_COPY) $(-RELEASE_DIR)

	@echo "compile coffee-script files"
	@$(-BIN_COFFEE) -cb $(-COFFEE_RELEASE)
	@rm -f $(-COFFEE_RELEASE)

	@echo "all codes in \"$(-RELEASE_DIR)\""


test-cov: clean
	@echo 'copy files'
	@mkdir -p $(-COVERAGE_DIR)
	@cp -r $(-COVERAGE_COPY) $(-COVERAGE_DIR)

	@echo "compile coffee-script files"
	@$(-BIN_COFFEE) -cb $(-COFFEE_COVERAGE)
	@rm -f $(-COFFEE_COVERAGE)

	@echo "generate coverage files"
	@$(-BIN_JSCOVER) $(-COVERAGE_DIR)/lib $(-COVERAGE_DIR)/lib

	@echo "run test"
	@$(-BIN_MOCHA) \
		--reporter tap \
		$(-COVERAGE_TESTS)

	@echo "make coverage report"

	@if [ `echo $$OSTYPE | grep -c 'darwin'` -eq 1 ]; then \
		echo "coverage info"; \
		$(-BIN_MOCHA) \
			--reporter html-cov \
			$(-COVERAGE_TESTS) \
			> $(-COVERAGE_FILE); \
		echo "test report saved \"$(-COVERAGE_FILE)\""; \
		open $(-COVERAGE_FILE); \
	else \
		$(-BIN_MOCHA) \
			--reporter json-cov \
			$(-COVERAGE_TESTS) \
			> $(-COVERAGE_DIR)/cov.json; \
		echo "cov = require './$(-COVERAGE_DIR)/cov.json'\npad = (num) ->\n  if num < 10 then '   ' + num.toString()\n  else if num < 100 then '  ' + num.toString()\n  else if num < 1000 then ' ' + num.toString()\n  else num.toString()\ncolor = (cover) ->\n  if cover >= 90 then '\x1B[32m'\n  else if cover >= 80 then '\x1B[36m'\n  else if cover >= 70 then '\x1B[33m'\n  else '\x1B[31m'\nend = '\x1B[0m'\nconsole.log '---------- \x1B[36mSummary' + end + ' ----------'\nconsole.log 'coverage: ', color(cov.coverage) + Math.round(cov.coverage) + '%' + end\nconsole.log 'sloc:     ', cov.sloc, 'lines'\nconsole.log 'hits:     ', cov.hits, 'lines'\nconsole.log 'misses:   ', cov.misses, 'lines'\nfor file in cov.files\n  console.log '---- \x1B[36m' + file.filename+':', color(file.coverage) + Math.round(file.coverage) + '%', end + '----'\n  for num, line of file.source\n    if line.coverage is 0 \n      head = '\x1B[31m'\n    else\n      head = '\x1B[32m'\n    console.log head + pad(num), '|', line.source + end" | $(-BIN_COFFEE) --stdio ; \
	fi

.-PHONY: default

clean:
	@echo 'clean'
	@-rm -fr out
	@-rm -f coverage.html


