#!/bin/bash

# Set bash script to exit immediately if any commands fail.
set -e

DEBUG=0
POD_INSTALL=0
# Git tag version
VERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
SCHEMES=(
    "SentryIssueRepo"
)

build="${PWD}/build"
release="${build}/release"

echo "🧹 Clear directories $build $release"

rm -rf "$build"
rm -rf "$release"

mkdir -p "$build"
mkdir -p "$release"

start=`date +%s`

# Console IO
while test $# -gt 0; do
    case "$1" in
    -h|--help)
        echo -e "Release StackConsentManager usage description"
        echo -e " "
        echo -e "./build.sh [options]"
        echo -e " "
        echo -e "options:"
        echo -e "-h, --help           Shows brief help"
        echo -e "-d, --debug          Build debug frameworks to release directory without compression and uploading"
        echo -e "-pi, --pod_install      Updates CocoaPods Environment before build"
        exit 0
        ;;
    -d|--debug)
        export DEBUG=1
        shift
        ;;
    -pi|--pod_install)
        export POD_INSTALL=1
        shift
        ;;
    *)
        break
        ;;
    esac
done

# Function to check if CocoaPods is installed
check_cocoapods() {
    if ! command -v pod &> /dev/null
    then
        echo "CocoaPods is not installed. Installing CocoaPods..."
        sudo gem install cocoapods
    else
        echo "CocoaPods is already installed."
    fi
}

# Update pods
if [[ $POD_INSTALL == 1 ]]; then
    check_cocoapods
    echo "Running pod install..."
    pod install --repo-update
fi

# Ensure we are opening the correct workspace
echo "Current directory: $(pwd)"
echo "Checking for SentryIssueRepo.xcworkspace..."

if [ ! -d "SentryIssueRepo.xcworkspace" ]; then
    echo "Error: .xcworkspace directory not found. Make sure CocoaPods ran successfully."
    exit 1
else
    echo "Found SentryIssueRepo.xcworkspace."
fi

# Clean the build directory
echo "Cleaning the build directory..."
xcodebuild clean -workspace "SentryIssueRepo.xcworkspace" -scheme "${SCHEMES[0]}" -configuration Debug

# Build the static library for device and for simulator (using all needed architectures).
echo "🔨 Build components"
for scheme in ${SCHEMES[@]}; do
    echo "Building $scheme for iOS device..."
    xcodebuild archive \
        -workspace "SentryIssueRepo.xcworkspace" \
        -scheme "$scheme" \
        -archivePath "$build/ios.xcarchive" \
        -sdk iphoneos \
        VALID_ARCHS="arm64 armv7" \
        GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
        STRIP_INSTALLED_PRODUCT=YES \
        LINK_FRAMEWORKS_AUTOMATICALLY=NO \
        OTHER_CFLAGS="-fembed-bitcode -Qunused-arguments" \
        ONLY_ACTIVE_ARCH=NO \
        DEPLOYMENT_POSTPROCESSING=YES \
        MACH_O_TYPE=staticlib \
        IPHONEOS_DEPLOYMENT_TARGET=12.0 \
        DEBUG_INFORMATION_FORMAT="dwarf" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_ENTITLEMENTS="" \
        CODE_SIGNING_ALLOWED=NO | xcpretty

    if [ ! -f "$build/ios.xcarchive/Products/usr/local/lib/lib$scheme.a" ]; then
        echo "Error: Static library not found in ios.xcarchive for $scheme."
        ls -l "$build/ios.xcarchive/Products/usr/local/lib"
        exit 1
    fi

    if [ ! -d "$build/ios.xcarchive/Products/usr/local/include" ]; then
        echo "Error: Headers not found in ios.xcarchive for $scheme."
        ls -l "$build/ios.xcarchive/Products/usr/local"
        exit 1
    fi

    echo "Building $scheme for iOS simulator..."
    xcodebuild archive \
        -workspace "SentryIssueRepo.xcworkspace" \
        -scheme "$scheme" \
        -archivePath "$build/ios_sim.xcarchive" \
        -sdk iphonesimulator \
        VALID_ARCHS="x86_64 arm64" \
        GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
        STRIP_INSTALLED_PRODUCT=YES \
        LINK_FRAMEWORKS_AUTOMATICALLY=NO \
        OTHER_CFLAGS="-fembed-bitcode -Qunused-arguments" \
        ONLY_ACTIVE_ARCH=NO \
        DEPLOYMENT_POSTPROCESSING=YES \
        MACH_O_TYPE=staticlib \
        IPHONEOS_DEPLOYMENT_TARGET=12.0 \
        DEBUG_INFORMATION_FORMAT="dwarf" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_ENTITLEMENTS="" \
        CODE_SIGNING_ALLOWED=NO | xcpretty

    if [ ! -f "$build/ios_sim.xcarchive/Products/usr/local/lib/lib$scheme.a" ]; then
        echo "Error: Static library not found in ios_sim.xcarchive for $scheme."
        ls -l "$build/ios_sim.xcarchive/Products/usr/local/lib"
        exit 1
    fi

    if [ ! -d "$build/ios_sim.xcarchive/Products/usr/local/include" ]; then
        echo "Error: Headers not found in ios_sim.xcarchive for $scheme."
        ls -l "$build/ios_sim.xcarchive/Products/usr/local"
        exit 1
    fi

    echo "Creating XCFramework for $scheme..."
    xcodebuild -create-xcframework \
        -library "$build/ios.xcarchive/Products/usr/local/lib/lib$scheme.a" \
        -headers "$build/ios.xcarchive/Products/usr/local/include" \
        -library "$build/ios_sim.xcarchive/Products/usr/local/lib/lib$scheme.a" \
        -headers "$build/ios_sim.xcarchive/Products/usr/local/include" \
        -output "$release/$scheme.xcframework"

    if [ ! -d "$release/$scheme.xcframework" ]; then
        echo "Error: XCFramework not created for $scheme."
        exit 1
    fi

    echo "XCFramework for $scheme created successfully."
done

if [[ "$DEBUG" != "1" ]]; then
    echo "🗜 Compress packages"
    cd "$release"
    zip -r "SentryIssueRepo.zip" * > /dev/null
    echo "🌎 Upload"
    aws s3 cp "$(PWD)/SentryIssueRepo.zip" "s3://appodeal-ios/SentryIssueRepo/$VERSION/SentryIssueRepo.zip" --acl public-read
fi

end=`date +%s`
runtime=$((end-start))
echo "🚀 Build finished in $runtime seconds"
