!include($$top_srcdir/compiler_flags.pri) { error() }

QT += core

SOURCES += \
    pitch_test.cc \
    scale_test.cc

# 'pri' usage based on http://archive.is/https://www.toptal.com/qt/vital-guide-qmake
!include(./lib.pri) { error() }
!include(../util/util.pri) { error() }
!include(../libtests/libtestmain.pri) { error() }
!include(../libstyles/libstyles.pri) { error() }
!include(../lib_app/fluidsynth_linkonly.pri) { error() }
!include(../../third_party/googletest-release-1.8.0/googletest/googletest.pri) { error() }
!include(../../third_party/googletest-release-1.8.0/googlemock/googlemock.pri) { error() }

target.path = $$top_exe_dir
INSTALLS += target
