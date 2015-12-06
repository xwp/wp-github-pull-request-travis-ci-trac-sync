#!/bin/bash
# encoding: utf-8
#
# Sync from GitHub Pull Requests to WordPress Trac via Travis CI (see Trac #34694)
# Project URL: https://github.com/xwp/wp-github-pull-request-travis-ci-trac-sync
#
# By Weston Ruter, XWP.
# Incorporates trac-attach.sh from Andrew Nacin and Mike Adams: https://gist.github.com/nacin/4758127
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2 or, at
# your discretion, any later version, as published by the Free
# Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

# Dev note: Do not use `-x` to verbosely echo the commands, as this will leak the Trac user password.

CUSTOM_SCRIPT_DIR=/tmp/wp-github-pull-request-travis-ci-trac-sync
if [[ ! -e "$CUSTOM_SCRIPT_DIR" ]]; then
	git clone https://github.com/xwp/wp-github-pull-request-travis-ci-trac-sync.git "$CUSTOM_SCRIPT_DIR"
fi

npm install -g travis-after-all
AFTER_ALL_EXIT_CODE=0
if ! travis-after-all; then
	AFTER_ALL_EXIT_CODE="$?"
fi

if [[ "$AFTER_ALL_EXIT_CODE" == 0 ]]; then
	TEST_RESULT_MSG="✅ PASS" # Note the first character is a emoji checkmark.
elif [[ "$AFTER_ALL_EXIT_CODE" == 1 ]]; then
	TEST_RESULT_MSG="❌ FAIL" # Note the first character is a emoji cross mark.
elif [[ "$AFTER_ALL_EXIT_CODE" == 3 ]]; then
	echo "Something went wrong, perhaps a failure to connect to the Travis CI API."
	exit 1
else
	echo "travis-after-all return code: $AFTER_ALL_EXIT_CODE"
	return 0
fi

if [[ "$TRAVIS_JOB_NUMBER" != *.1 ]]; then
	echo "Skipping Trac patch for job $TRAVIS_JOB_NUMBER. Only upload for first job."
	return 0
fi

BRANCH_HEAD_COMMIT="$( sed "s/.*\.\.\.//" <<< "$TRAVIS_COMMIT_RANGE" )"
BRANCH_PARENT_COMMIT="$( git rev-list --boundary $(git rev-parse --abbrev-ref $BRANCH_HEAD_COMMIT)...$TRAVIS_BRANCH | grep ^- | cut -c2- | head -n1 )"

git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git fetch origin
BRANCH_NAME="$( git branch -r --list --contains "$BRANCH_HEAD_COMMIT" | grep 'trac' | head -n1 | cut -c3- | sed 's:^origin/::' )"
TICKET_NUMBER=$(sed 's:^trac.\([0-9]*\).*:\1:' <<< "$BRANCH_NAME")

echo "BRANCH_NAME: $BRANCH_NAME"
echo "BRANCH_PARENT_COMMIT: $BRANCH_PARENT_COMMIT"
echo "BRANCH_HEAD_COMMIT: $BRANCH_HEAD_COMMIT"
echo "TICKET_NUMBER: $TICKET_NUMBER"
echo "TRAVIS_COMMIT: $TRAVIS_COMMIT"
echo "TRAVIS_COMMIT_RANGE: $TRAVIS_COMMIT_RANGE"

if ! grep -qE '^[1-9][0-9]*$' <<< "$TICKET_NUMBER"; then
	echo "Failed to parse Trac ticket number out of TRAVIS_BRANCH: $BRANCH_NAME"
	echo "Try branch names like 'trac-12345', 'trac/12345', or 'trac-12345-some-summary'."
	exit 1
fi

if ! curl -f "https://core.trac.wordpress.org/ticket/$TICKET_NUMBER" > /tmp/trac-ticket.html; then
	echo "Unable to find Trac ticket $TICKET_NUMBER."
	exit 1
fi

if [[ ! "$WPORG_USERNAME" ]]; then
	echo "Environment variable not set: WPORG_USERNAME"
	echo "Also make sure that WPORG_PASSWORD is set."
	exit 1
fi
if [[ ! "$TRAVIS_REPO_SLUG" ]]; then
	echo "Missing environment variable: TRAVIS_REPO_SLUG"
	exit 1
fi
if [[ ! "$TRAVIS_PULL_REQUEST" ]] || [[ false == "$TRAVIS_PULL_REQUEST" ]]; then
	echo "Missing or 'false' environment variable: TRAVIS_PULL_REQUEST"
	return 0
fi
if [[ ! "$TRAVIS_COMMIT" ]] && [[ -n "$TRAVIS_COMMIT_RANGE" ]]; then
	echo "Missing environment variable: TRAVIS_COMMIT or TRAVIS_COMMIT_RANGE"
	exit 1
fi

PATCH_FILENAME_PREFIX=$(tr '/' '.' <<< "$TRAVIS_REPO_SLUG")
PULL_REQUEST_URL="https://github.com/$TRAVIS_REPO_SLUG/pull/$TRAVIS_PULL_REQUEST"
BUILD_URL="https://travisci.org/$TRAVIS_REPO_SLUG/builds/$TRAVIS_BUILD_NUMBER"
COMMIT_AUTHORS="$(git log "$TRAVIS_BRANCH..$BRANCH_HEAD_COMMIT" --format="%aN" | sort -u | paste -d/ -s - | sed 's:/:, :g')"
COMMIT_COUNT="$(git rev-list "$TRAVIS_BRANCH..$BRANCH_HEAD_COMMIT" --count)"
SHORT_COMMIT_RANGE="$( sed 's:\([0-9a-f]\{8\}\)[0-9a-f]*:\1:g' <<< "$BRANCH_PARENT_COMMIT...$BRANCH_HEAD_COMMIT" )"
SHORT_DELTA_COMMIT_RANGE="$SHORT_COMMIT_RANGE"
PREVIOUS_COMMIT_ATTACHED=""

# Get the attachment for patch
# @todo Replace the following with an XML-RPC call to get the list of attachments.
PATCH_FILENAME_PATTERN="/raw-attachment/ticket/$TICKET_NUMBER/$PATCH_FILENAME_PREFIX\.$TICKET_NUMBER\.pr$TRAVIS_PULL_REQUEST\.[0-9a-f\.]*\..*diff"
echo "PATCH_FILENAME_PATTERN: $PATCH_FILENAME_PATTERN"
if ! grep -Eo '<a href="'"$PATCH_FILENAME_PATTERN"'" class="trac-rawlink"' /tmp/trac-ticket.html | sed 's:.*"\(/raw-attachment[^"]*\)".*:\1:' > /tmp/existing-attachments.txt; then
	echo "There are no existing attachments for this PR on the ticket."
else
	echo "Existing Trac attachments for this PR:"
	cat /tmp/existing-attachments.txt

	SHORT_COMMIT_HASH=$( tail -n1 /tmp/existing-attachments.txt | sed 's/.*\.\.\.\([0-9a-f][0-9a-f]*\)\..*/\1/' )
	if grep -sqE '^[0-9a-f][0-9a-f]*$' <<< "$SHORT_COMMIT_HASH"; then
		PREVIOUS_COMMIT_ATTACHED="$SHORT_COMMIT_HASH"
		SHORT_DELTA_COMMIT_RANGE=$( sed 's:\([0-9a-f]\{8\}\)[0-9a-f]*:\1:g' <<< "$PREVIOUS_COMMIT_ATTACHED...$BRANCH_HEAD_COMMIT" )
	else
		echo "Unable to parse PREVIOUS_COMMIT_ATTACHED from existing-attachments.txt ($SHORT_COMMIT_HASH)"
	fi
fi

PATCH_FILENAME="$PATCH_FILENAME_PREFIX.$TICKET_NUMBER.pr$TRAVIS_PULL_REQUEST.$SHORT_DELTA_COMMIT_RANGE.diff"
git diff --no-prefix "$TRAVIS_COMMIT_RANGE" > "/tmp/$PATCH_FILENAME"

if [[ "$COMMIT_COUNT" == 1 ]]; then
	CHANGESET_URL="https://github.com/$TRAVIS_REPO_SLUG/commit/$BRANCH_HEAD_COMMIT"
else
	CHANGESET_URL="https://github.com/$TRAVIS_REPO_SLUG/compare/$SHORT_DELTA_COMMIT_RANGE"
fi

ATTACHMENT_DESCRIPTION="PR [$PULL_REQUEST_URL $TRAVIS_PULL_REQUEST], ±Δ [$CHANGESET_URL $SHORT_DELTA_COMMIT_RANGE], Tests: [$BUILD_URL $TEST_RESULT_MSG]

$( git log --reverse --format="* %s (by %aN)" "$SHORT_DELTA_COMMIT_RANGE" )
"

echo "PREVIOUS_COMMIT_ATTACHED: $PREVIOUS_COMMIT_ATTACHED"
echo "SHORT_COMMIT_RANGE: $SHORT_COMMIT_RANGE"
echo "SHORT_DELTA_COMMIT_RANGE: $SHORT_DELTA_COMMIT_RANGE"
echo "COMMIT_COUNT: $COMMIT_COUNT"
echo "ATTACHMENT_DESCRIPTION: $ATTACHMENT_DESCRIPTION"

# Props Nacin and Mike Adams: https://gist.github.com/nacin/4758127
TRAC_SUBDOMAIN=core

echo "<?xml version=\"1.0\"?>
<methodCall>
	<methodName>ticket.putAttachment</methodName>
	<params>
		<param><int>${TICKET_NUMBER}</int></param>
		<param><string>${PATCH_FILENAME}</string></param>
		<param><base64>$( base64 <<< "$ATTACHMENT_DESCRIPTION" )</base64></param>
		<param><base64>$( cat "/tmp/$PATCH_FILENAME" | base64  )</base64></param>
		<param><boolean>0</boolean></param>
	</params>
</methodCall>" > /tmp/xml-rpc-request

echo "XML-RPC Request:"
cat /tmp/xml-rpc-request
echo

curl -u "${WPORG_USERNAME}:${WPORG_PASSWORD}" -s -H "Content-Type: application/xml; charset=utf-8" --data "@/tmp/xml-rpc-request" "https://${TRAC_SUBDOMAIN}.trac.wordpress.org/login/xmlrpc" > /tmp/xml-rpc-response

if grep -qs '<name>faultCode</name>' /tmp/xml-rpc-response; then
	echo "XML-RPC returned with faultCode:"
	cat /tmp/xml-rpc-response
	exit 1
fi

echo "XML-RPC Response:"
cat /tmp/xml-rpc-response

ATTACHED=$(cat /tmp/xml-rpc-response | grep "${TICKET_NUMBER}" | sed -e 's/<value><string>//' -e 's/<\/string><\/value>//')

if [[ "$ATTACHED" ]]; then
	echo "Patch uploaded to Trac at:"
	echo "http://${TRAC_SUBDOMAIN}.trac.wordpress.org/attachment/ticket/${TICKET_NUMBER}/${ATTACHED}"
else
	echo "Failed to get attached file."
	exit 1
fi
