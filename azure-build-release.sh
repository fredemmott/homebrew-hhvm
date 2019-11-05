#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -ex

# Check that this commit is in the correct format to trigger a build.
NUM_FILES="$(git diff --name-only HEAD^ HEAD | grep -c ^builds/)"
if [ "$NUM_FILES" != "1" ]; then
  echo "Invalid commit. Expected 1 file, got $NUM_FILES files."
  exit 1
fi

FILE="$(git diff --name-only HEAD^ HEAD | grep ^builds/)"
source "$FILE"

if [ -z "$VERSION" ]; then
  echo "Committed file must set VERSION."
  exit 1
fi

# If a build for a specific MacOS version was requested, exit on all other
# versions.
CURRENT=$(sw_vers -productVersion | cut -d . -f 1,2)
if [ -n "$PLATFORM" -a "$PLATFORM" != "$CURRENT" ]; then
  echo "Requested build for Mac OS X $PLATFORM but we are on $CURRENT."
  echo "Nothing to do here, good bye."
  exit 0
fi

# When SKIP_IS_DONE is set, exit if the package is already built.
if [ -n "$SKIP_IF_DONE" ]; then
  case "$CURRENT" in
    10.13) CODENAME="macos-high_sierra";;
    10.14) CODENAME="macos-mojave";;
    *)
      echo "Unable to determine codename for Mac OS X $CURRENT."
      exit 1
  esac

  brew upgrade
  brew install jq

  if (
    curl --retry 5 "https://hhvm.com/api/build-status/$VERSION" \
      | jq .succeeded | grep "\"$CODENAME\""
  ); then
    echo "Package for Mac OS X $CURRENT has already been successfully built."
    echo "Nothing to do here, good bye."
    exit 0
  fi
fi

git checkout master
git pull --rebase

./azure-build-release.sh "$VERSION"
