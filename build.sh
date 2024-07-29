#!/bin/bash

# 1
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
        echo -e "-pi, --pod_install	  Updates CocoaPods Environment before build"
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

# 2
# Update pods
if [[ $POD_INSTALL == 1 ]]; then
	pod install
fi

# 3
# Build the framework for device and for simulator (using
# all needed architectures).
echo "🔨 Build components"
for scheme in ${SCHEMES[@]}; do
	 xcodebuild archive \
        -scheme "$scheme" \
        -archivePath "./build/ios.xcarchive" \
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

    # iOS simulator
    xcodebuild archive \
        -scheme "$scheme" \
        -archivePath "./build/ios_sim.xcarchive" \
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

    xcodebuild -create-xcframework \
        -framework "$build/ios.xcarchive/Products/Library/Frameworks/$scheme.framework" \
        -framework "$build/ios_sim.xcarchive/Products/Library/Frameworks/$scheme.framework" \
        -output "$release/$scheme.xcframework"
	
	# swift package compute-checksum "$release/$scheme.xcframework"
done

end=`date +%s`
runtime=$((end-start))
echo "🚀 Build finished at: $runtime seconds"
