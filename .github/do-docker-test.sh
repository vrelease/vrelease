#!/bin/bash

set -ex

run_test() {
    ./committer
    docker run \
        --rm \
        -e VRELEASE_AUTH_TOKEN="$VRELEASE_AUTH_TOKEN" \
        -v "${GITHUB_WORKSPACE}:/wd" \
        vrelease $@
    sleep 5
}

run_test
run_test -d
run_test -l 5
run_test -d -n
run_test -a committer
run_test -c -a committer
run_test -a committer -d -l 8
run_test -i -c -a committer
