#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

printf "${GREEN}Starting musl libc porting for NullOS...${NC}\n"

# 1. Prepare directory
mkdir -p userspace/extra
cd userspace/extra

# 2. Download musl
if [ ! -d "musl" ]; then
    printf "${GREEN}Cloning musl libc...${NC}\n"
    git clone https://git.musl-libc.org/git/musl
else
    printf "${GREEN}musl already cloned, updating...${NC}\n"
    cd musl
    git pull
    cd ..
fi

cd musl

# 3. Configure musl
# Since NullOS syscalls match x86_64 Linux, we can start with that.
# We'll build a static library first.
printf "${GREEN}Configuring musl...${NC}\n"

# We use the cross compiler defined in the project
# Based on userspace/config.mk: CC = x86_64-linux-gnu-gcc or gcc
export CC=gcc
export AR=ar
export RANLIB=ranlib

./configure \
    --prefix=$(pwd)/../musl-install \
    --target=x86_64 \
    --disable-shared

# 4. Build and Install
printf "${GREEN}Building musl...${NC}\n"
make -j$(nproc)

printf "${GREEN}Installing musl...${NC}\n"
make install

printf "${GREEN}musl libc ported and installed to userspace/extra/musl-install${NC}\n"
