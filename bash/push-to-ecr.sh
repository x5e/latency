#!/usr/bin/env bash
set -e
if test "${TRAVIS_EVENT_TYPE}" = pull_request; then
    echo "Not pushing to ECR on pull request."
    exit 0
fi
cd "$(dirname $0)"/..
`aws ecr get-login --no-include-email --region us-east-1`
GIT_BRANCH=`cat travis_branch.txt 2> /dev/null || git symbolic-ref -q --short HEAD`
GIT_SHORT=`git rev-parse --short HEAD`
docker build -t latency .
ACCT=401701269211
docker tag latency ${ACCT}.dkr.ecr.us-east-1.amazonaws.com/latency:${GIT_BRANCH}
docker tag latency ${ACCT}.dkr.ecr.us-east-1.amazonaws.com/latency:${GIT_SHORT}
docker push ${ACCT}.dkr.ecr.us-east-1.amazonaws.com/latency:${GIT_BRANCH}
docker push ${ACCT}.dkr.ecr.us-east-1.amazonaws.com/latency:${GIT_SHORT}

