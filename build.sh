#!/usr/bin/env bash
set -e

# Check chat_id and token
if [[ -z $chat_id ]]; then
    echo "error: please fill your CHAT_ID secret!"
    exit 1
fi

if [[ -z $token ]]; then
    echo "error: please fill TOKEN secret!"
    exit 1
fi

mkdir -p android-kernel && cd android-kernel

## Variables
GKI_VERSION="android12-5.10"
WORKDIR=$(pwd)
export TZ="Asia/Makassar"
export KBUILD_BUILD_USER="ambatubash69"
export KBUILD_BUILD_HOST="gacorprjkt"
export KBUILD_BUILD_TIMESTAMP=$(date)

ANYKERNEL_REPO="https://github.com/ambatubash69/Anykernel3"
ANYKERNEL_BRANCH="gki"

KERNEL_REPO="https://github.com/ambatubash69/gki_android12-5.10"
KERNEL_BRANCH="master"
DEFCONFIG="gki_defconfig"
KERNEL_IMAGE="$WORKDIR/out/arch/arm64/boot/Image"

USE_AOSP_CLANG="false"
AOSP_CLANG_VERSION="r547379"

USE_CUSTOM_CLANG="true"
CUSTOM_CLANG_SOURCE="https://github.com/XSans0/WeebX-Clang/releases/download/WeebX-Clang-19.1.5-release/WeebX-Clang-19.1.5.tar.gz"
CUSTOM_CLANG_BRANCH=""
CUSTOM_CLANG_COMMAND=""

MAKE_FLAGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 O=$WORKDIR/out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"

RANDOM_HASH=$(head -c 20 /dev/urandom | sha1sum | head -c 7)
ZIP_NAME="ambatubash69-KVER-OPTIONE-$RANDOM_HASH.zip"

# Import telegram functions
source $WORKDIR/../telegram_functions.sh

# if ksu = yes
if [[ $USE_KSU == "yes" ]]; then
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE/KSU/g')
elif [[ $USE_KSU_NEXT == "yes" ]]; then
    # if ksu-next = yes
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE/KSU_NEXT/g')
else
    # if ksu = no
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE-//g')
fi

## Install needed packages
sudo apt update -y
sudo apt install -y git ccache automake flex lzop bison gperf build-essential zip curl zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc unzip device-tree-compiler python2 rename libelf-dev dwarves zstd

# Clone kernel source
git clone --depth=1 $KERNEL_REPO -b $KERNEL_BRANCH $WORKDIR/common

# Clone AnyKernel
git clone --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" $WORKDIR/anykernel

## Extract kernel version
cd $WORKDIR/common
KERNEL_VERSION=$(make kernelversion)
ZIP_NAME=$(echo "$ZIP_NAME" | sed "s/KVER/$KERNEL_VERSION/g")
cd $WORKDIR

## Download Toolchains
mkdir $WORKDIR/clang
if [[ $USE_AOSP_CLANG == "true" ]]; then
    wget -qO $WORKDIR/clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$AOSP_CLANG_VERSION.tar.gz || {
        echo "Invalid AOSP Clang version"
        exit 1
    }
    tar -xf $WORKDIR/clang.tar.gz -C $WORKDIR/clang/
    rm -f $WORKDIR/clang.tar.gz
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gas/linux-x86 $WORKDIR/gas
elif [[ $USE_CUSTOM_CLANG == "true" ]]; then
    if [[ $CUSTOM_CLANG_SOURCE =~ git ]]; then
        if [[ $CUSTOM_CLANG_SOURCE == *'.tar.'* ]]; then
            wget -q $CUSTOM_CLANG_SOURCE
            tar -C $WORKDIR/clang/ -xf $WORKDIR/*.tar.*
            rm -f $WORKDIR/*.tar.*
        else
            rm -rf $WORKDIR/clang
            git clone $CUSTOM_CLANG_SOURCE -b $CUSTOM_CLANG_BRANCH $WORKDIR/clang --depth=1
        fi
    else
        if [[ -n $CUSTOM_CLANG_COMMAND ]]; then
            bash -c "$CUSTOM_CLANG_COMMAND"
        else
            echo "Clang source is not supported, please specify CUSTOM_CLANG_COMMAND"
            exit 1
        fi
    fi

elif [[ $USE_AOSP_CLANG == "true" ]] && [[ $USE_CUSTOM_CLANG == "true" ]]; then
    echo "You have to choose one, AOSP Clang or Custom Clang!"
    exit 1
else
    echo "stfu."
    exit 1
fi

if [[ $USE_CUSTOM_CLANG == "true" ]]; then
    export PATH="$WORKDIR/clang/bin:$PATH"
elif [[ $USE_AOSP_CLANG == "true" ]]; then
    export PATH="$WORKDIR/clang/bin:$WORKDIR/gas:$PATH"
fi

COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

## KSU or KSU-Next setup
if [[ $USE_KSU_NEXT == "yes" ]]; then
    if [[ $USE_KSU_SUSFS == "yes" ]]; then
        KSU_NEXT_BRANCH=next-susfs-$(echo "$GKI_VERSION" | sed 's/ndroid//g')
    elif [[ $USE_KSU_SUSFS != "yes" ]]; then
        KSU_NEXT_BRANCH=next
    fi

    wget -qO $WORKDIR/setup.sh https://raw.githubusercontent.com/rifsxd/KernelSU-Next/refs/heads/next/kernel/setup.sh
    chmod +x $WORKDIR/setup.sh
    bash $WORKDIR/setup.sh "$KSU_NEXT_BRANCH"
    cd $WORKDIR/KernelSU-Next
    REPO_LINK=$(git config --get remote.origin.url)
    KSU_NEXT_VERSION=$(git ls-remote --tags $REPO_LINK | grep -o 'refs/tags/.*' | grep -v '\^{}' | sed 's#refs/tags/##' | sort -V | tail -n 1)
    cd $WORKDIR
elif [[ $USE_KSU == "yes" ]]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
    cd $WORKDIR/KernelSU
    KSU_VERSION=$(git describe --abbrev=0 --tags)
    cd $WORKDIR
elif [[ $USE_KSU_NEXT == "yes" ]] && [[ $USE_KSU == "yes" ]]; then
    echo
    echo "Bruh"
    exit 1
fi

## Apply kernel patches
git config --global user.email "kontol@example.com"
git config --global user.name "Your Name"

## SUSFS4KSU
if [[ $USE_KSU == "yes" ]] || [[ $USE_KSU_NEXT == "yes" ]] && [[ $USE_KSU_SUSFS == "yes" ]]; then
    git clone --depth=1 "https://gitlab.com/simonpunk/susfs4ksu" -b "gki-$GKI_VERSION" $WORKDIR/susfs4ksu
    SUSFS_PATCHES="$WORKDIR/susfs4ksu/kernel_patches"

    cd $WORKDIR/common
    if [[ $USE_KSU == "yes" ]]; then
        ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/KSU/KSUxSUSFS/g')
        cp $SUSFS_PATCHES/50_add_susfs_in_gki-$GKI_VERSION.patch .
        cp $SUSFS_PATCHES/fs/susfs.c ./fs/
        cp $SUSFS_PATCHES/include/linux/susfs.h ./include/linux/
        cp $SUSFS_PATCHES/fs/sus_su.c ./fs/
        cp $SUSFS_PATCHES/include/linux/sus_su.h ./include/linux/
        cd $WORKDIR/KernelSU
        cp $SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch .
        patch -p1 <10_enable_susfs_for_ksu.patch || exit 1
        cd $WORKDIR/common
        patch -p1 <50_add_susfs_in_gki-$GKI_VERSION.patch || exit 1
    elif [[ $USE_KSU_NEXT == "yes" ]]; then
        ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/KSU_NEXT/KSU_NEXTxSUSFS/g')
        cp $SUSFS_PATCHES/50_add_susfs_in_gki-$GKI_VERSION.patch .
        cp $SUSFS_PATCHES/fs/susfs.c ./fs/
        cp $SUSFS_PATCHES/include/linux/susfs.h ./include/linux/
        cp $SUSFS_PATCHES/fs/sus_su.c ./fs/
        cp $SUSFS_PATCHES/include/linux/sus_su.h ./include/linux/
        patch -p1 <50_add_susfs_in_gki-$GKI_VERSION.patch || exit 1
    fi

    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')

elif [[ $USE_KSU_SUSFS == "yes" ]] && [[ $USE_KSU != "yes" ]] && [[ $USE_KSU_NEXT != "yes" ]]; then
    echo "You can't use SUSFS without KSU or KSU-Next enabled!"
    exit 1
fi

cd $WORKDIR

text=$(
    cat <<EOF
*~~~ GKI Build Started ~~~*
*GKI Version*: \`$GKI_VERSION\`
*Kernel Version*: \`$KERNEL_VERSION\`
*Build Status*: \`$STATUS\`
*Date*: \`$KBUILD_BUILD_TIMESTAMP\`
*KSU*: \`$([[ $USE_KSU == "yes" ]] && echo "true" || echo "false")\`
*KSU Version*: \`$([[ $USE_KSU == "yes" ]] && echo "$KSU_VERSION" || echo "null")\`
*KSU-Next*: \`$([[ $USE_KSU_NEXT == "yes" ]] && echo "true" || echo "false")\`
*KSU-Next Version*: \`$([[ $USE_KSU_NEXT == "yes" ]] && echo "$KSU_NEXT_VERSION" || echo "null")\`
*SUSFS*: \`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "true" || echo "false")\`
*SUSFS Version*: \`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "$SUSFS_VERSION" || echo "null")\`
*Compiler*: \`$COMPILER_STRING\`
EOF
)

send_msg "$text"

# Build GKI
cd $WORKDIR/common
set +e
(
    make $MAKE_FLAGS $DEFCONFIG
    make $MAKE_FLAGS -j$(nproc --all)
) 2>&1 | tee $WORKDIR/build.log
set -e
cd $WORKDIR

# Upload to telegram
if ! [[ -f $KERNEL_IMAGE ]]; then
    send_msg "❌ GKI Build failed!"
    upload_file "$WORKDIR/build.log"
    exit 1
else
    send_msg "✅ GKI Build succeeded"

    ## Zipping
    cd $WORKDIR/anykernel
    sed -i "s/DUMMY1/$KERNEL_VERSION/g" anykernel.sh

    if [[ $USE_KSU != "yes" ]] && [[ $USE_KSU_NEXT != "yes" ]]; then
        sed -i "s/KSUDUMMY2 //g" anykernel.sh
    elif [[ $USE_KSU != "yes" ]] && [[ $USE_KSU_NEXT == "yes" ]]; then
        sed -i "s/KSU/KSU-Next/g" anykernel.sh
    fi

    if [[ $USE_KSU_SUSFS != "yes" ]]; then
        sed -i "s/DUMMY2//g" anykernel.sh
    elif [[ $USE_KSU_SUSFS == "yes" ]]; then
        sed -i "s/DUMMY2/xSUSFS/g" anykernel.sh
    fi

    cp $KERNEL_IMAGE .
    zip -r9 $ZIP_NAME * -x LICENSE
    mv $ZIP_NAME $WORKDIR
    cd $WORKDIR
    upload_file "$WORKDIR/$ZIP_NAME"
    upload_file "$WORKDIR/build.log"
    exit 0
fi