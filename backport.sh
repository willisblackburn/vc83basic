#!/bin/bash

# Backport the latest commit on the current branch to the previous branch.
# The "previous" branch is hard-coded in this script; in each branch the "previous" branch is different.
# Since the script itself will be replaced when running "git checkout," we do that in a subshell and then have the
# subshell re-run this script after the checkout.

PREVIOUS_BRANCH=e11-1

LATEST_COMMIT=$(git rev-parse HEAD)
echo Backporting $LATEST_COMMIT to $PREVIOUS_BRANCH

/bin/bash -c "git checkout $PREVIOUS_BRANCH && git cherry-pick $LATEST_COMMIT && git push && $0"
