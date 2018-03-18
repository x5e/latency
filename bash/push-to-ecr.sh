#!/usr/bin/env bash
set -e
NAME=${1:-latency}
test -n "${AWS_DEFAULT_REGION}"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
echo "REGION=${REGION}"
if test "${TRAVIS_EVENT_TYPE}" = pull_request; then
    echo "Not pushing to ECR on pull request."
    exit 0
fi
cd "$(dirname $0)"/..
echo getting AWS account number
ACCT=`aws sts get-caller-identity | jq -r .Account`
echo AWS account number is ${ACCT}
echo getting ECR login
`aws ecr get-login --no-include-email --region ${REGION}`
GIT_BRANCH=`cat travis_branch.txt 2> /dev/null || git symbolic-ref -q --short HEAD`
GIT_SHORT=`git rev-parse --short HEAD`
echo Building docker image...
docker build -t ${NAME} .
echo finished building docker image
aws ecr create-repository --repository-name ${NAME} &> /dev/null || true
docker tag ${NAME} ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${NAME}:${GIT_BRANCH}
docker tag ${NAME} ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${NAME}:${GIT_SHORT}
docker push ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${NAME}:${GIT_BRANCH}
docker push ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${NAME}:${GIT_SHORT}

