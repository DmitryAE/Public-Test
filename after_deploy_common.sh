#!/bin/bash

echo "<------- START READING PARAMETERS ------->"
errorParameters()
{
   echo ""
   echo "Usage: $0 -reponame GITHUB_REPO_NAME -version VERSION"
   echo -e "\t-reponame Github Repository Name"
   echo -e "\t-version Version number of SDK"
   echo "<------- FAILED READING PARAMETERS ------->"
   exit 1 # Exit script after printing help
}

while getopts "reponame:version:" opt
do
   case "$opt" in
      reponame ) GITHUB_REPO_NAME="$OPTARG" ;;
      version ) VERSION="$OPTARG" ;;
      ? ) errorParameters ;; # Print helpFunction in case parameter is non-existent
   esac
done
echo "<------- SUCCESS READING PARAMETERS ------->"

echo ${GITHUB_REPO_NAME}
echo ${VERSION}
exit 1

echo "<------- START CHECKING ENVIRONMENT ------->"
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "Missing GITHUB_TOKEN environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    exit 1
fi
if [ -z "${GITLAB_ACCESS_TOKEN}" ]; then
    echo "Missing GITLAB_ACCESS_TOKEN environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    exit 1
fi
if [ -z "${GITHUB_REPO_NAME}" ]; then
    echo "Missing GITHUB_REPO_NAME environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    exit 1
fi
if [ -z "${VERSION}" ]; then
    echo "Missing VERSION environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    exit 1
fi

echo "<------- SUCCESS CHECKING ENVIRONMENT ------->"

GITHUB_ACCOUNT_NAME="Kameleoon"
GITHUB_REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_ACCOUNT_NAME}/${GITHUB_REPO_NAME}.git"
EMAIL_SDK="sdk@kameleoon.com"

echo "<------- START CLONE REPO ------->"
# Init github repository inside deploy folder
rm -rf "${GITHUB_REPO_NAME}"

git clone "${GITHUB_REPO_URL}"
if [ $? -ne 0 ]; then
    echo "Please check your GITHUB_TOKEN key"
    echo "<------- FAILED CLONE REPO ------->"
    exit 1
fi

echo "<------- START UPDATE CHANGELOG ------->"
cd ${GITHUB_REPO_NAME}

# Git config to "${EMAIL_SDK}"
CURRENT_EMAIL=$(git config --global user.email)
git config --global user.email "${EMAIL_SDK}"

# Commit and push updated files
sed -n -e "/## ${VERSION}/,/##/ p" ../CHANGELOG.md | sed -e '$ d' > new-changes.md
sed -i '/`internal`/d' new-changes.md
sed -i '3 r new-changes.md' CHANGELOG.md
CURRENT_DATE=$(date +"%Y-%m-%d")
sed -i "s/## ${VERSION}/## ${VERSION} - ${CURRENT_DATE}/" CHANGELOG.md
rm new-changes.md

git add *
git commit -m "GO SDK ${VERSION}"
git push --force
if [ $? -ne 0 ]; then
    echo "<------- FAILED UPDATE CHANGELOG ------->"
    exit 1
fi

# Remove deploy folder
cd ../
rm -rf "${GITHUB_REPO_NAME}"

echo "<------- SUCCESS UPDATE CHANGELOG ------->"

GITLAB_DEVELOPMENT_FOLDER="developers"
GITLAB_DEVELOPMENT_REPO_URL="http://oauth2:${GITLAB_ACCESS_TOKEN}@development.kameleoon.net/kameleoon-documentation/${GITLAB_DEVELOPMENT_FOLDER}.git"
PATH_TO_FILE="source/includes/_go_sdk.md"

echo "<------- START CLONE DOCUMENT REPO ------->"
rm -rf "${GITLAB_DEVELOPMENT_REPO_URL}"

git clone "${GITLAB_DEVELOPMENT_REPO_URL}"
if [ $? -ne 0 ]; then
    echo "<------- FAILED CLONE DOCUMENT REPO ------->"
    exit 1
fi
echo "<------- SUCCESS CLONE DOCUMENT REPO ------->"

echo "<------- START UPDATE DOCUMENT VERSION ------->"
cd ${GITLAB_DEVELOPMENT_FOLDER}
sed -i "s/SDK: [^0-9.]*\([0-9.]*\)/SDK: ${VERSION}/g" ${PATH_TO_FILE}
git add *
git commit -m "Automatic Update: GO SDK ${VERSION}"
git push
if [ $? -ne 0 ]; then
    echo "<------- FAILED UPDATE DOCUMENT VERSION ------->"
    exit 1
fi
echo "<------- SUCCESS UPDATE DOCUMENT VERSION ------->"

# Git config revert
git config --global user.email $CURRENT_EMAIL

echo "Finished to update repo to version ${VERSION}"