#!/bin/bash

# Adapted from gtk:.gitlab-ci/android-sdk.sh (GTK main, LGPL-2.1-or-later)
# Original author: Florian "sp1rit" <sp1rit@disroot.org>
#
# Installs the Android SDK components required for the pixiewood build and
# pre-accepts the SDK licenses non-interactively. Expects sdkmanager to be
# available already (GitHub-hosted runners ship the Android SDK).
#
# Required env vars:
#   ANDROID_HOME    SDK install location
#   ANDROID_SDKVER  build-tools version, e.g. 36.1.0
#   ANDROID_NDKVER  NDK version, e.g. 29.0.14206865

set -e
set -x

if [ -z $ANDROID_HOME -o -z $ANDROID_SDKVER -o -z $ANDROID_NDKVER ]; then
    echo "ANDROID_HOME, ANDROID_SDKVER and ANDROID_NDKVER env var must be set!"
    exit 1
fi

test -d ${HOME}/.android || mkdir ${HOME}/.android
# there are currently zero user repos
echo 'count=0' > ${HOME}/.android/repositories.cfg
cat <<EOF >> ${HOME}/.android/sites-settings.cfg
@version@=1
@disabled@https\://dl.google.com/android/repository/extras/intel/addon.xml=disabled
@disabled@https\://dl.google.com/android/repository/glass/addon.xml=disabled
@disabled@https\://dl.google.com/android/repository/sys-img/android/sys-img.xml=disabled
@disabled@https\://dl.google.com/android/repository/sys-img/android-tv/sys-img.xml=disabled
@disabled@https\://dl.google.com/android/repository/sys-img/android-wear/sys-img.xml=disabled
@disabled@https\://dl.google.com/android/repository/sys-img/google_apis/sys-img.xml=disabled
EOF

ANDROID_SDKMAJOR=`echo ${ANDROID_SDKVER} | awk -F '.' '{print $1}'`

# accepted licenses

mkdir -p $ANDROID_HOME/licenses/

cat << EOF > $ANDROID_HOME/licenses/android-sdk-license

8933bad161af4178b1185d1a37fbf41ea5269c55

d56f5187479451eabf01fb78af6dfcb131a6481e

24333f8a63b6825ea9c5514f83c2829b004d1fee
EOF

cat <<EOF > $ANDROID_HOME/licenses/android-sdk-preview-license

84831b9409646a918e30573bab4c9c91346d8abd
EOF

cat <<EOF > $ANDROID_HOME/licenses/android-sdk-preview-license-old

79120722343a6f314e0719f863036c702b0e6b2a

84831b9409646a918e30573bab4c9c91346d8abd
EOF

cat <<EOF > $ANDROID_HOME/licenses/intel-android-extra-license

d975f751698a77b662f1254ddbeed3901e976f5a
EOF

SDKMANAGER=`command -v sdkmanager || echo "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"` #ANDROID_HOME may not contain a space :(
${SDKMANAGER} --sdk_root=${ANDROID_HOME} \
	"build-tools;${ANDROID_SDKVER}" \
	"ndk;${ANDROID_NDKVER}" \
	"platforms;android-${ANDROID_SDKMAJOR}"
