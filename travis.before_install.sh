#!/bin/bash

CUSTOM_SCRIPT_DIR=/tmp/wp-github-pull-request-travis-ci-trac-sync
if [[ ! -e "$CUSTOM_SCRIPT_DIR" ]]; then
	git clone https://github.com/xwp/wp-github-pull-request-travis-ci-trac-sync.git "$CUSTOM_SCRIPT_DIR"
fi

if [[ "$TRAVIS_PULL_REQUEST" != 'false' ]]; then
	# Include only the files added/modified in scope to check.
	# @todo If it is NOT a pull request, we could use the last stable branch instead of $TRAVIS_BRANCH.
	git diff --diff-filter=AM --no-prefix --unified=0 $TRAVIS_BRANCH...$TRAVIS_COMMIT -- . | php "$CUSTOM_SCRIPT_DIR/parse-diff-ranges.php" > /tmp/scope
else
	# Include all files in repo in scope to check.
	find . -type f | sed 's:^\.//*::' > /tmp/scope
fi

echo "# PHP diffs:"
cat /tmp/scope | grep -E '\.php(:|$)' | tee /tmp/scope-php

echo "# JS diffs:"
cat /tmp/scope | grep -E '\.(js|json|jshintrc)(:|$)' | tee /tmp/scope-js

echo "# CSS diffs:"
cat /tmp/scope | grep -E '\.(css|scss)(:|$)' | tee /tmp/scope-scss

echo "# XML diffs:"
cat /tmp/scope | grep -E '\.(xml|svg|xml.dist)(:|$)' | tee /tmp/scope-xml

echo "# YML diffs:"
cat /tmp/scope | grep -E '\.(yml|)(:|$)' | tee /tmp/scope-yml

if [[ "$TRAVIS_PULL_REQUEST" != 'false' ]] && [[ "$WP_TRAVISCI" == 'travis:phpunit' ]] && [[ $( wc -l < /tmp/scope-php ) == 0 ]]; then
	echo "Canceling phpunit and PHP syntax check job because no changes to PHP files on branch"
	# @todo travis cancel "$TRAVIS_JOB_NUMBER"
	exit 0
fi

if [[ "$WP_TRAVISCI" == "travis:js" ]]; then
	mkdir -p /tmp/phpcs && curl -L https://github.com/squizlabs/PHP_CodeSniffer/archive/master.tar.gz | tar xz --strip-components=1 -C /tmp/phpcs
	mkdir -p /tmp/wpcs && curl -L https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards/archive/master.tar.gz | tar xz --strip-components=1 -C /tmp/wpcs
	/tmp/phpcs/scripts/phpcs --config-set installed_paths /tmp/wpcs
	npm install -g jscs
fi
