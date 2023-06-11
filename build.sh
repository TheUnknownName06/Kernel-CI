#!/bin/bash

TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
NAME_KERNEL_FILE="$1"
chat_id="$TG_CHAT"
token="$TG_TOKEN"

#INFROMATION NAME KERNEL
export KBUILD_BUILD_USER=$(grep kbuild_user $NAME_KERNEL_FILE | cut -f2 -d"=" )
export LOCALVERSION=$(grep local_version $NAME_KERNEL_FILE | cut -f2 -d"=" )
NAME_KERNEL=$(grep name_zip $NAME_KERNEL_FILE | cut -f2 -d"=" )
VENDOR_NAME=$(grep vendor_name $NAME_KERNEL_FILE | cut -f2 -d"=" )
DEVICE_NAME=$(grep device_name $NAME_KERNEL_FILE | cut -f2 -d"=" )

#INFORMATION GATHER LINK
LINK_KERNEL=$(grep link_kernel $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_GCC_AARCH64=$(grep link_gcc_aarch64 $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_GCC_ARM=$(grep link_gcc_arm $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_CLANG=$(grep link_clang $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_anykernel=$(grep link_anykernel $NAME_KERNEL_FILE | cut -f2 -d"=" )

initial_kernel() {
   git clone --depth=1 --recurse-submodules -j8 --single-branch $LINK_KERNEL ~/kernel
   cd ~/kernel
}

clone_git() {
  # download toolchains
  git clone --depth=1 $LINK_anykernel ~/AnyKernel
  
  #proton clang
  #git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
  
  #clang 14
  git clone --depth=1 $LINK_CLANG clang

  # BY ZYCROMERZ
  # git clone --depth=1 https://github.com/ZyCromerZ/aarch64-zyc-linux-gnu -b 13 aarch64-gcc
  # git clone --depth=1 https://github.com/ZyCromerZ/arm-zyc-linux-gnueabi -b 13 aarch32-gcc

  # BY ETERNAL COMPILER
  git clone --depth=1 $LINK_GCC_AARCH64 aarch64-gcc
  git clone --depth=1 $LINK_GCC_ARM aarch32-gcc
}

cleaning_cache() {
  if [ -f ~/log_build.txt ]; then
    rm -rf ~/log_build.txt
  fi
  if [ -d out ]; then
    rm -rf out
  fi
  if [ -d HASIL ]; then
    rm -rf HASIL/**
  fi
  if [ -d ~/AnyKernel ]; then
    rm -rf ~/AnyKernel
  fi
}

sticker() {
  curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
    -d sticker="CAACAgEAAxkBAAEnKnJfZOFzBnwC3cPwiirjZdgTMBMLRAACugEAAkVfBy-aN927wS5blhsE" \
    -d chat_id=$chat_id
}

sendinfo() {
  curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d chat_id="$chat_id" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="<b>$NAME_KERNEL</b>%0ABuild started on <code>CirrusCI</code>%0AFor device ${DEVICE_NAME} %0A | Build By <b>$KBUILD_BUILD_USER</b> | Local Version: $LOCALVERSION | branch <code>$(git rev-parse --abbrev-ref HEAD)</code> (master)%0AUnder commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0AUsing compiler: <code>$(~/kernel/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/ */ /g')</code>%0AStarted on <code>$(date)</code>%0A<b>Build Status:</b> Beta"
}

push() {
  cd ~/AnyKernel
  mv ~/log_build.txt .
  sha512_hash="$(sha512sum ${NAME_KERNEL}-*.zip | cut -f1 -d ' ')"
  ZIP=$(echo ${NAME_KERNEL}-*.zip)
  curl -F document=@$ZIP -F document=@log_build.txt "https://api.telegram.org/bot$token/sendDocument" \
    -F chat_id="$chat_id" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For ${DEVICE_NAME} | Build By <b>$KBUILD_BUILD_USER</b> | Local Version: $LOCALVERSION | <b>$(${GCC}gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</b> | <b>SHA512SUM</b>: <code>$sha512_hash</code>"
}


error_handler() {
  cd ~/AnyKernel
  ~/log_build.txt
  ZIP=log_build.txt
  curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
    -F chat_id="$chat_id" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="Build encountered an error. took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For ${DEVICE_NAME} | Build By <b>$KBUILD_BUILD_USER</b> | Local Version: $LOCALVERSION"
  exit 1
}

compile() {
  #ubah nama kernel dan dev builder
  printf "\nFinal Repository kernel Should Look Like...\n" && ls -lAog
  export ARCH=arm64

  #mulai mengcompile kernel
  [ -d "out" ] && rm -rf out
  mkdir -p out

  make O=out ARCH=arm64 even_defconfig

  PATH="${PWD}/clang/bin:${PATH}:${PWD}/aarch32-gcc/bin:${PATH}:${PWD}/aarch64-gcc/bin:${PATH}" \
  make -j$(nproc --all) O=out \
    ARCH=arm64 \
    CC="clang" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${PWD}/aarch64-gcc/bin/aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="${PWD}/aarch32-gcc/bin/arm-linux-gnueabihf-" \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    V=0 2>&1 | tee log.txt

  cp out/arch/arm64/boot/Image.gz-dtb ~/AnyKernel
}

zipping() {
  cd ~/AnyKernel
  echo $NAME_KERNEL > name_kernel.txt
  zip -r9 ${NAME_KERNEL}-${VENDOR_NAME}-${TANGGAL}.zip *
  cd ..
}

trap 'error_handler' ERR
{
initial_kernel
cleaning_cache
clone_git
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
} 2>&1 | tee ~/log_build.txt
push
