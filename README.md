# Sync from GitHub Pull Requests to WordPress Trac via Travis CI

This script facilitates contributing to WordPress Core via GitHub Pull Requests. See WordPress Trac [#34694](https://core.trac.wordpress.org/ticket/34694).

_Caveat:_ This is intended for users in trusted contributor teams as it requires the user
to open open an internal (intra-repo) pull request from feature branch to `master`.
It will not work when opening a pull request from a fork due to Travis CI's [security restrictions](https://docs.travis-ci.com/user/pull-requests#Security-Restrictions-when-testing-Pull-Requests)
on environment variables. So any pull requests from external contributors will
need to be manually applied to a feature branch by a repo contributor and then
open an intra-repo pull request (while closing the original inter-repo pull request).

## Installation

1. Clone the `develop.git.wordpress.org` repo onto GitHub and enable Travis CI for it. See instructions in [Contributing to WordPress Core via GitHub](https://make.xwp.co/2015/10/29/contributing-to-wordpress-core-via-github/).
2. Create a bot user on WordPress.org (e.g. `xwp-bot`) and request that the `XML_RPC` privilege be granted for that user.
3. Ensure the patch from Trac [#34694](https://core.trac.wordpress.org/ticket/34694) is applied to WordPress Core; if not already upstreamed, make it the first commit to each feature branch.
4. Edit the Travis CI settings for your WordPress GitHub clone to add the following environment variables:
 * `WP_TRAVISCI_CUSTOM_BEFORE_INSTALL_SRC`: https://raw.githubusercontent.com/xwp/wp-github-pull-request-travis-ci-trac-sync/master/travis.before_install.sh
 * `WP_TRAVISCI_CUSTOM_SCRIPT_SRC`: https://raw.githubusercontent.com/xwp/wp-github-pull-request-travis-ci-trac-sync/master/travis.script.sh
 * `WP_TRAVISCI_CUSTOM_AFTER_SCRIPT_SRC`: https://raw.githubusercontent.com/xwp/wp-github-pull-request-travis-ci-trac-sync/master/travis.after_script.sh
 * `WPORG_USERNAME`: Use the Trac bot user you created.
 * `WPORG_PASSWORD`: Use password for Trac bot user, and make sure added with “Display value in build log” _off_.

For more information, see [Streamlining Contributions to WordPress Core via GitHub](https://make.xwp.co/2015/12/05/streamlining-contributions-to-wordpress-core-via-github/).

## Usage

Once configured, a developer with write access to the GitHub repo can contribute to WordPress Core as follows:

0. Ensure that a [Trac](https://core.trac.wordpress.org/) ticket exists.
1. Push commits to a feature branch on GitHub named after the Trac ticket (e.g. `trac-12345`).
2. Open pull request to `master`; this must be an _internal_ (intra-repo) pull request, not from a fork (inter-repo).
3. Watch Travis CI run its tests, and when completed look at Trac to see the patch uploaded.

As a bonus, the changes in the pull request will also have the following checks run:

* Modified PHP files will be checked for syntax errors.
* PHP changes will be checked with PHP_CodeSniffer against the `WordPress-Core` and `WordPress-Docs` standards.
* JS changes will be checked with JSCS against the `wordpress` preset.

Note that if there are no PHP files modified in a pull request, the *PHPUnit tests will be _skipped_ altogether*, drastically speeding up the build time.

## Background

For an the initial post that describes the approach, as linked above, see [Streamlining Contributions to WordPress Core via GitHub](https://make.xwp.co/2015/12/05/streamlining-contributions-to-wordpress-core-via-github/).

For a prior post describing the manual workflow that is being streamlined here, also as linked above, see [Contributing to WordPress Core via GitHub](https://make.xwp.co/2015/10/29/contributing-to-wordpress-core-via-github/).

## Credits

Written by Weston Ruter ([westonruter](https://profiles.wordpress.org/westonruter)), [XWP](https://xwp.co/).

The functionality incorporates logic from [`trac-attach.sh`](https://gist.github.com/nacin/4758127) by Andrew Nacin ([nacin](https://profiles.wordpress.org/nacin)) and Michael Adams ([mdawaffe](https://profiles.wordpress.org/mdawaffe/)).

License GPLv2.
