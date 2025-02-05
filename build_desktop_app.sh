#!/bin/bash

#
# Copyright (c) 2020, 219 Design, LLC
# See LICENSE.txt
#
# https://www.219design.com
# Software | Electrical | Mechanical | Product Design
#

set -Eeuxo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

pushd .
trap "popd" EXIT HUP INT QUIT TERM

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR  # enter this script's directory. (in case called from root of repository)

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
  exit 1
else
  qmakecmd=qmake
  MYAPP_EXTRA_CONF=""
  # adding this next line here (rather than in run_all_tests.sh), because we think
  # of the graph-generation as more of a "build" step than a "test":
  $DIR/sw_arch_doc/generate_graph.sh ${DIR}/src/ ${DIR}/
fi

if [ -f fluidsynth/.git ]; then
  echo "Skipping any work in fluidsynth submodule. Looks done already."
else
  git submodule update --init fluidsynth
fi

pushd fluidsynth >& /dev/null
  git checkout CMakeLists.txt # in case our last Android build left it dirty
popd >& /dev/null
mkdir -p build/fsynth_for_desktop
pushd build/fsynth_for_desktop >& /dev/null
  cmake --version # to print the version to CI logs.
  cmake -DCMAKE_BUILD_TYPE=Debug ../../fluidsynth/
  make VERBOSE=1 DESTDIR=./gcc_64
  make VERBOSE=1 DESTDIR=./gcc_64 install
popd >& /dev/null

# See https://github.com/pestophagous/heory/issues/34
$DIR/tools/ci/patch_fluid_headers.sh \
  $DIR/fluidsynth/src/midi/fluid_midi.h \
  $DIR/patch_fluid_midi.h.patch \
  $DIR/build/fsynth_for_desktop/gcc_64/usr/local/include

$DIR/tools/ci/version.sh

source $DIR/path_to_qmake.bash

pushd build >& /dev/null

  # When you need release: CONFIG+=release
  ${qmakecmd} $MYAPP_EXTRA_CONF CONFIG+=force_debug_info "$DIR" # note: debug INFO (symbols) are ok even in release

  if [[ -n ${GITHUB_ACTIONS-} || -n ${BITBUCKET_REPO_OWNER-} || -n ${BITBUCKET_REPO_FULL_NAME-} ]];
  then
    # we have to skip the apptest(s) on GitHub for now (alsa dummy module won't load)
    make CPPFLAGS_DEF_QSTYLE="HEORY_APPTEST_SKIPTHIS"
  else
    # https://stackoverflow.com/questions/17578150/add-cflags-to-qmake-project-without-hard-coding-them-in-the-pro-file
    # https://stackoverflow.com/questions/7754218/qmake-how-to-add-and-use-a-variable-into-the-pro-file
    make CPPFLAGS_DEF_QSTYLE="HEORY_APPTEST"
  fi

  make install # puts necessary items side-by-side with app exe

popd >& /dev/null

pushd $DIR/build/src/apptest >& /dev/null
  rm collection.o
  make CPPFLAGS_DEF_QSTYLE="HEORY_BOGUSVAR" # make without HEORY_APPTEST (so we ensure it builds with and without it)
  rm collection.o
popd >& /dev/null
