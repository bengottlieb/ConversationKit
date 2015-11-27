#!/bin/sh

#  BuildFramework.sh
#  FrameworkTest
#
#  Created by Ben Gottlieb on 11/14/15.
#  Copyright (c) 2015 Stand Alone, Inc. All rights reserved.

BASE_BUILD_DIR=${BUILD_DIR}
FRAMEWORK_NAME="ConversationKit"
IOS_SUFFIX=""
UNIVERSAL_OUTPUTFOLDER="Build/${CONFIGURATION}-universal"

GIT_BRANCH=`git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/"`
GIT_REV=`git rev-parse --short HEAD`

BUILD_DATE=`date`

IOS_PLIST_PATH="${PROJECT_DIR}/ConversationKit/iOS/info.plist"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :branch"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :rev"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :built"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Add :branch string ${GIT_BRANCH}"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Add :rev string ${GIT_REV}"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Add :built string ${BUILD_DATE}"

# make sure the output directory exists
mkdir -p "${UNIVERSAL_OUTPUTFOLDER}"

# Step 1. Build Device and Simulator versions
xcodebuild -target "${PROJECT_NAME}" -configuration ${CONFIGURATION} -sdk iphoneos ONLY_ACTIVE_ARCH=NO  BUILD_DIR="${BASE_BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build
xcodebuild -target "${PROJECT_NAME}" -configuration ${CONFIGURATION} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO BUILD_DIR="${BASE_BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build

# Step 2. Copy the framework structure (from iphoneos build) to the universal folder
echo "copying device framework"
cp -R "${BASE_BUILD_DIR}/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework" "${UNIVERSAL_OUTPUTFOLDER}/"

# Step 3. Copy Swift modules (from iphonesimulator build) to the copied framework directory
echo "integrating sim framework"
cp -R "${BASE_BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework/Modules/${FRAMEWORK_NAME}${IOS_SUFFIX}.swiftmodule/" "${UNIVERSAL_OUTPUTFOLDER}/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework/Modules/${FRAMEWORK_NAME}${IOS_SUFFIX}.swiftmodule/"

# Step 4. Create universal binary file using lipo and place the combined executable in the copied framework directory
echo "lipo'ing files"
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework/${FRAMEWORK_NAME}${IOS_SUFFIX}" "${BASE_BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework/${FRAMEWORK_NAME}${IOS_SUFFIX}" "${BASE_BUILD_DIR}/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}${IOS_SUFFIX}.framework/${FRAMEWORK_NAME}${IOS_SUFFIX}"

/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :branch"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :rev"
/usr/libexec/PlistBuddy "${IOS_PLIST_PATH}" -c "Delete :built"

# Step 5. Convenience step to copy the framework to the project's directory
mkdir -p "${PROJECT_DIR}/iOS Framework/"
rm -rf "${PROJECT_DIR}/iOS Framework/${FRAMEWORK_NAME}.framework"
cp -R "${UNIVERSAL_OUTPUTFOLDER}/${FRAMEWORK_NAME}.framework" "${PROJECT_DIR}/iOS Framework"


# Step 7. Convenience step to open the project's directory in Finder
open "${PROJECT_DIR}"
