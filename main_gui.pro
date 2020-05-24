#
# Copyright (c) 2020, 219 Design, LLC
# See LICENSE.txt
#
# https://www.219design.com
# Software | Electrical | Mechanical | Product Design
#
!include($$top_srcdir/compiler_flags.pri) { error() } # each subproject must also include this

TEMPLATE = subdirs

SUBDIRS = \
    app \
    apptest \
    lib \
    lib_tests \
    libstyles \
    libtestmain \
    third_party/googletest-release-1.8.0/googlemock \
    third_party/googletest-release-1.8.0/googletest \
    util

app.file = src/app/app.pro
apptest.file = src/apptest/apptest.pro
lib.file = src/lib/lib.pro
lib_tests.file = src/lib/lib_tests.pro
libstyles.file = src/libstyles/libstyles.pro
libtestmain.file = src/libtests/libtestmain.pro
util.file = src/util/util.pro

# third_party projects
googlemock.file = third_party/googletest-release-1.8.0/googlemock/googlemock.pro
googletest.file = third_party/googletest-release-1.8.0/googletest/googletest.pro

# The 'app' does not directly depend on this entire set of libraries.
# Instead, think of this massive dependency list as a way for us to tell qmake
# that "the install directory of app" indeed depends on (aka 'wishes to
# contain') all these libraries.
app.depends = \
    apptest \
    lib \
    lib_tests \
    libstyles \
    libtestmain \
    third_party/googletest-release-1.8.0/googlemock \
    third_party/googletest-release-1.8.0/googletest \
    util

# The remaining 'depends' lines are used in the 'traditional' sense of actually
# specifying the miminum link-time dependencies of each item:

# NOTE: using 'CONFIG += ordered' is considered a bad practice—prefer using .depends instead.
googlemock.depends = third_party/googletest-release-1.8.0/googletest
apptest.depends = lib util
lib.depends = libstyles util
lib_tests.depends = lib util libtestmain third_party/googletest-release-1.8.0/googletest third_party/googletest-release-1.8.0/googlemock
libtestmain.depends = third_party/googletest-release-1.8.0/googletest third_party/googletest-release-1.8.0/googlemock
