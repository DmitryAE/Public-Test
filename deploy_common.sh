#!/bin/bash

echo "<------- START READING PARAMETERS ------->"
errorParameters()
{
   echo ""
   echo "Usage: $0 GITHUB_REPO_NAME VERSION"
   echo -e "\t-reponame Github Repository Name"
   echo -e "\t-version Version number of SDK"
   echo "<------- FAILED READING PARAMETERS ------->"
   exit 1 # Exit script after printing help
}
GITHUB_REPO_NAME=$1
SDK_NAME=$2
VERSION=$3
PATH_TO_FILE=$4
echo "<------- SUCCESS READING PARAMETERS ------->"

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
    errorParameters()
    exit 1
fi
if [ -z "${VERSION}" ]; then
    echo "Missing VERSION environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    errorParameters()
    exit 1
fi
if [ -z "${SDK_NAME}" ]; then
    echo "Missing SDK_NAME environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    errorParameters()
    exit 1
fi
if [ -z "${PATH_TO_FILE}" ]; then
    echo "Missing PATH_TO_FILE environment variable"
    echo "<------- FAILED CHECKING ENVIRONMENT ------->"
    errorParameters()
    exit 1
fi
echo "<------- SUCCESS CHECKING ENVIRONMENT ------->"

GITHUB_ACCOUNT_NAME="Kameleoon"
GITHUB_REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_ACCOUNT_NAME}/${GITHUB_REPO_NAME}.git"
EMAIL_SDK="sdk@kameleoon.com"
DESC_NEW_VERSION=$(sed -n -e "/## $VERSION/,/##/ p" CHANGELOG.md | sed -e '1d;$d' | sed -r '/^\s*$/d' | sed 's/* /- /g' | awk '{ printf "%s\\n",$0 }' | sed 's/"/\\"/g')

echo "<------- START CLONE REPO ------->"
# Init github repository inside deploy folder
rm -rf "${GITHUB_REPO_NAME}"

git clone "${GITHUB_REPO_URL}"
if [ $? -ne 0 ]; then
    echo "Please check your GITHUB_TOKEN key"
    echo "<------- FAILED CLONE REPO ------->"
    exit 1
fi

echo "<------- START COMMIT CODE ------->"
COMMIT_CODE_SCRIPT="scripts/commit_code.sh"
if [ -f "$COMMIT_CODE_SCRIPT" ]; then
    mv CHANGELOG.md CHANGELOG-GITHUB.md
    echo "Run a script to commit open source code to repo"
    sh "${COMMIT_CODE_SCRIPT}" ${GITHUB_REPO_NAME}
    mv CHANGELOG-GITHUB.md CHANGELOG.md
else 
    echo "No open source code was commited"
fi
echo "<------- SUCCESS COMMIT CODE ------->"

echo "<------- START UPDATE CHANGELOG ------->"
cd ${GITHUB_REPO_NAME}

#Update changes in CHANGELOG
sed -n -e "/## ${VERSION}/,/##/ p" ../CHANGELOG.md | sed -e '$ d' > new-changes.md
sed -i '/`internal`/d' new-changes.md
sed -i '3 r new-changes.md' CHANGELOG.md
CURRENT_DATE=$(date +"%Y-%m-%d")
sed -i "s/## ${VERSION}/## ${VERSION} - ${CURRENT_DATE}/" CHANGELOG.md
rm new-changes.md
echo "<------- SUCCESS UPDATE CHANGELOG ------->"

echo "<------- START DELETE SERVICE FILES ------->"
# Delete service files
rm CHANGELOG-GITHUB.md
rm deploy_common.sh
echo "<------- SUCCESS DELETE SERVICE FILES ------->"

echo "<------- START PUSH TO GITHUB ------->"
# Git config to "${EMAIL_SDK}"
CURRENT_EMAIL=$(git config --global user.email)
git config --global user.email "${EMAIL_SDK}"

# Commit and push updated files
git add *
git commit -m "${SDK_NAME} ${VERSION}"
git push --force
if [ $? -ne 0 ]; then
    echo "<------- FAILED PUSH TO GITHUB ------->"
    exit 1
fi

# Create tag and push
git tag "${VERSION}" main
git push origin "${VERSION}"

# Remove deploy folder
cd ../
rm -rf "${GITHUB_REPO_NAME}"
echo "<------- SUCCESS PUSH TO GITHUB ------->"

echo "<------- START UPDATE ARTIFACTORY REPO ------->"
UPDATE_ARTIFACTORY="scripts/update_artifactory.sh"
if [ -f "$UPDATE_ARTIFACTORY" ]; then
    echo "Run a script to update artifactory repo"
    sh "${UPDATE_ARTIFACTORY}"
else 
    echo "Artifacrory repo wasn't updated"
fi
echo "<------- SUCCESS UPDATE ARTIFACTORY REPO ------->"

echo "<------- START MAKE A NEW RELEASE ON GITHUB ------->"
GH_REPO="https://api.github.com/repos/$GITHUB_ACCOUNT_NAME/$GITHUB_REPO_NAME"
GH_TAGS="$GH_REPO/releases/tags/$VERSION"
AUTH="Authorization: token $GITHUB_TOKEN"

# Validate token.
curl -o /dev/null -sH "$AUTH" $GH_REPO || { echo "Error: Invalid repo, token or network issue!";  exit 1; }

# Create a release
RELEASE_URL="https://api.github.com/repos/$GITHUB_ACCOUNT_NAME/$GITHUB_REPO_NAME/releases"
curl -sH "$AUTH" --data "{\"tag_name\": \"$VERSION\", \"name\": \"${SDK_NAME} ${VERSION}\", \"body\": \"$DESC_NEW_VERSION\"}" $RELEASE_URL
echo $?

# Read asset tags.
response=$(curl -sH "$AUTH" $GH_TAGS)
echo $response
echo "<------- SUCCESS MAKE A NEW RELEASE ON GITHUB ------->"

echo "<------- START CLONE DOCUMENT REPO ------->"
GITLAB_DEVELOPMENT_FOLDER="developers"
GITLAB_DEVELOPMENT_REPO_URL="http://oauth2:${GITLAB_ACCESS_TOKEN}@development.kameleoon.net/kameleoon-documentation/${GITLAB_DEVELOPMENT_FOLDER}.git"

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
git commit -m "Automatic Update: ${SDK_NAME} ${VERSION}"
git push
if [ $? -ne 0 ]; then
    echo "<------- FAILED UPDATE DOCUMENT VERSION ------->"
    exit 1
fi
echo "<------- SUCCESS UPDATE DOCUMENT VERSION ------->"

# Git config revert
git config --global user.email $CURRENT_EMAIL

echo "Finished to update repo to version ${VERSION}"
