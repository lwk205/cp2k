#!/bin/bash -e

# author: Ole Schuett

# install Ubuntu packages
apt-get update -qq
apt-get install -qq --no-install-recommends \
    autoconf                               \
    autogen                                \
    automake                               \
    autotools-dev                          \
    ca-certificates                        \
    cmake                                  \
    git                                    \
    less                                   \
    libtool                                \
    make                                   \
    nano                                   \
    pkg-config                             \
    python                                 \
    rsync                                  \
    unzip                                  \
    wget

rm -rf /var/lib/apt/lists/*

# clone cp2k repository
git clone --quiet --recursive --depth=1 --single-branch -b master https://github.com/cp2k/cp2k.git /workspace/cp2k

#EOF
