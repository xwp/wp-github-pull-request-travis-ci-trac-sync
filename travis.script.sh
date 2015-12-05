#!/bin/bash

set -e

CUSTOM_SCRIPT_DIR=/tmp/wp-github-pull-request-travis-ci-trac-sync
if [[ ! -e "$CUSTOM_SCRIPT_DIR" ]]; then
	git clone https://github.com/xwp/wp-github-pull-request-travis-ci-trac-sync.git "$CUSTOM_SCRIPT_DIR"
fi

function remove_diff_range {
	sed 's/:[0-9][0-9]*-[0-9][0-9]*$//' | sort | uniq
}

if [[ $WP_TRAVISCI == "travis:phpunit" ]]; then
	# Check for PHP syntax errors (we do this here during travis:phpunit because different PHP versions are available)
	for php_file in $( cat /tmp/scope-php | remove_diff_range ); do
		php -lf "$php_file"
	done
fi

if [[ "$WP_TRAVISCI" == "travis:js" ]]; then

	# Run JSCS.
	if ! cat /tmp/scope-js | remove_diff_range | xargs --no-run-if-empty jscs --reporter=inlinesingle --verbose --config="$CUSTOM_SCRIPT_DIR/.jscsrc" > /tmp/jscs-report; then
		echo "## JSCS"
		cat /tmp/jscs-report | php "$CUSTOM_SCRIPT_DIR/filter-report-for-patch-ranges.php" /tmp/scope-js
	fi

	# Check PHP_CodeSniffer WordPress-Coding-Standards.
	if ! cat /tmp/scope-php | remove_diff_range | xargs --no-run-if-empty /tmp/phpcs/scripts/phpcs -s --report-emacs=/tmp/phpcs-report --standard="$CUSTOM_SCRIPT_DIR/phpcs.ruleset.xml"; then
		echo "## PHPCS"
		cat /tmp/phpcs-report | php "$CUSTOM_SCRIPT_DIR/filter-report-for-patch-ranges.php" /tmp/scope-php
	fi
fi

set +e
