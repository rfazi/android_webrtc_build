#!/usr/bin/env bash

function fatal_error() {
  echo "$1"
  exit 1
}

BASE=/webrtc

apt update && apt install -y git curl wget lsb-release python3 sudo

echo "----------------------------------------------------------------------------------"
echo "Configuring GIT..."
echo "----------------------------------------------------------------------------------"
git config --global user.name "John Doe"
git config --global user.email "jdoe@email.com"
git config --global core.autocrlf false
git config --global core.filemode false

mkdir -p $BASE
cd $BASE || fatal_error "Cannot change directory"

echo "----------------------------------------------------------------------------------"
echo "Downloading depot_tools..."
echo "----------------------------------------------------------------------------------"

if [ -d "depot_tools" ]
    then
        echo "Depot tools already downloaded"
    else
        git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    fi

export PATH=$BASE/depot_tools:$PATH
./depot_tools/update_depot_tools

echo "----------------------------------------------------------------------------------"
echo "Downloading WebRTC Android..."
echo "----------------------------------------------------------------------------------"
fetch --nohooks --no-history webrtc_android
gclient sync

echo "----------------------------------------------------------------------------------"
echo "Downloading dependencies..."
echo "----------------------------------------------------------------------------------"
cd src && ./build/install-build-deps.sh

echo "----------------------------------------------------------------------------------"
echo "Checkout last version..."
echo "----------------------------------------------------------------------------------"
git fetch --all && git checkout origin/master

echo "----------------------------------------------------------------------------------"
echo "Preparing compilation environment..."
echo "----------------------------------------------------------------------------------"

function generateNinjaBuild() {
  gn gen out/Release_"$1" --args='target_os="android" target_cpu="'"$1"'" target_environment="device" proprietary_codecs=true rtc_use_h264=true is_debug=false symbol_level=1 dcheck_always_on=false is_official_build=true is_unsafe_developer_build=false rtc_build_examples=false rtc_include_tests=false'
}

generateNinjaBuild "arm"
generateNinjaBuild "arm64"
generateNinjaBuild "x86"
generateNinjaBuild "x64"

echo "----------------------------------------------------------------------------------"
echo "Compiling ARM..."
echo "----------------------------------------------------------------------------------"

function compileNinja() {
  ninja -C out/Release_"$1" -j 1
}

compileNinja "arm"

echo "----------------------------------------------------------------------------------"
echo "Compiling ARM64..."
echo "----------------------------------------------------------------------------------"

compileNinja "arm64"

echo "----------------------------------------------------------------------------------"
echo "Compiling x86..."
echo "----------------------------------------------------------------------------------"

compileNinja "x86"

echo "----------------------------------------------------------------------------------"
echo "Compiling x64..."
echo "----------------------------------------------------------------------------------"

compileNinja "x64"

echo "----------------------------------------------------------------------------------"
echo "Moving out java classes..."
echo "----------------------------------------------------------------------------------"
JAVA_FOLDER=$BASE/output/java/org/webrtc
mkdir -p $JAVA_FOLDER
cp -rv $BASE/src/sdk/android/src/java/org/webrtc/* $JAVA_FOLDER/
cp -rv $BASE/src/sdk/android/api/org/webrtc/* $JAVA_FOLDER/
cp -rv $BASE/src/rtc_base/java/src/org/webrtc/* $JAVA_FOLDER/
#cp -rv $BASE/src/modules/audio_device/android/java/src/org/webrtc/* $JAVA_FOLDER/
cp -rv $BASE/src/out/Release_arm/gen/sdk/android/video_api_java/generated_java/input_srcjars/org/webrtc/* $JAVA_FOLDER/
cp -rv $BASE/src/out/Release_arm/gen/sdk/android/peerconnection_java/generated_java/input_srcjars/org/webrtc/* $JAVA_FOLDER/

echo "----------------------------------------------------------------------------------"
echo "Moving out libs..."
echo "----------------------------------------------------------------------------------"
LIB_FOLDER=$BASE/output/libs
function moveLibs() {
  mkdir -p $LIB_FOLDER/"$1"
  cp -rv $BASE/src/out/Release_"$1"/libjingle_peerconnection_so.so $LIB_FOLDER/"$1"
}
moveLibs "arm"
moveLibs "arm64"
moveLibs "x86"
moveLibs "x64"

echo "----------------------------------------------------------------------------------"
echo "That's all :-)"
echo "You can find .so libs file under '$LIB_FOLDER' and .java files under '$JAVA_FOLDER'"
echo "----------------------------------------------------------------------------------"