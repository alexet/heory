//
// Copyright (c) 2020, pestophagous (pestophagous@users.noreply.github.com)
// See LICENSE.txt
//
// https://github.com/pestophagous/
//
#include "qml_message_interceptor.h"

#include <QtGlobal>

#include "util-assert.h"

#ifdef _MSC_VER
#    define strcasecmp _stricmp
#endif

namespace heory
{
struct QmlMessageInterceptor::Pimpl // "effectively private" due to no definition in header,
                                    // but provides full access to Interceptor
{
    explicit Pimpl( QmlMessageInterceptor* o ) : owner( o )
    {
        FASSERT( owner, "cannot be nullptr" );
    }

    void DecoratorFunc(
        QtMsgType type, const QMessageLogContext& context, const QString& message )
    {
        owner->DecoratorFunction(
            type, context, message ); // pass through to PRIVATE method of interceptor.
    }

    QmlMessageInterceptor* const owner;
};
namespace
{
    // QtMessageHandler is a typedef qtbase/src/corelib/global/qlogging.h
    QtMessageHandler original_handler = nullptr;
    QmlMessageInterceptor::Pimpl* our_interceptor = nullptr;

    bool EndsWith( const char* string_to_search, const char* target_suffix )
    {
        if( !string_to_search || !target_suffix )
        {
            return false;
        }

        // strrchr() returns a pointer to the LAST occurrence of the character
        const char* dot = strrchr( string_to_search, '.' );
        if( dot && !strcasecmp( dot, target_suffix ) )
        {
            return true;
        }

        const char* fslash = strrchr( string_to_search, '/' );
        if( fslash && !strcasecmp( fslash, target_suffix ) )
        {
            return true;
        }

        return false;
    }

    // Treat QML warnings as fatal.
    // Rationale: historically, a majority of QML warnings have indicated bugs.
    void FilterQmlWarnings( const char* file )
    {
        // NOTE: when using Qt RELEASE libraries (not debug), it may be
        // IMPOSSIBLE to ever match on '/qqmlapplicationengine.cpp' because they
        // seem to strip out file info (it shows "unknown") for the filename in
        // certain RELEASE/optimized qt builds.
        if( EndsWith( file, ".qml" ) || EndsWith( file, ".js" )
            || EndsWith( file, "/qqmlapplicationengine.cpp" ) )
        {
            FFAIL( "qml warning detected (in *qml or *js file). please fix it." );
        }
    }

    void DecoratorFunc(
        QtMsgType type, const QMessageLogContext& context, const QString& message )
    {
        FASSERT( our_interceptor, "you must assign to our_interceptor before we get here" );
        our_interceptor->DecoratorFunc( type, context, message );
    }

} // namespace

QmlMessageInterceptor::QmlMessageInterceptor( const bool suppressDefaultLogWhenSinkIsPresent )
    : m_threadId( std::this_thread::get_id() )
    , m_pimpl( new Pimpl( this ) )
    , m_suppressDefaultLogWhenSinkIsPresent( suppressDefaultLogWhenSinkIsPresent )
{
    FASSERT( original_handler == nullptr,
        "Qt supports just one handler at a time, so it would be "
        "an error to construct more than one of these" );
    FASSERT( our_interceptor == nullptr, "Qt supports just one handler at a time, so it would "
                                         "be an error to construct more than one of these" );
    our_interceptor = m_pimpl;
    original_handler = qInstallMessageHandler( DecoratorFunc );
}

QmlMessageInterceptor::~QmlMessageInterceptor()
{
    FASSERT( original_handler, "should be impossible for this to be null here" );
    qInstallMessageHandler( original_handler );
    original_handler = nullptr;
    delete m_pimpl;
}

void QmlMessageInterceptor::AddMessageSink( std::weak_ptr<std::function<void(
        QtMsgType type, const QMessageLogContext& context, const QString& message )>>
        sink )
{
    m_sinks.push_back( sink );
}

void QmlMessageInterceptor::DecoratorFunction(
    QtMsgType type, const QMessageLogContext& context, const QString& message )
{
    const int activeTees = TeeToSinks( type, context, message );

    if( 0 == activeTees || !m_suppressDefaultLogWhenSinkIsPresent )
    {
        // pass through to original Qt handler:
        original_handler( type, context, message );
    }

    switch( type )
    {
        // debug and info messages don't need special treatment
    case QtDebugMsg:
    case QtInfoMsg:
        break;

        // warnings (and worse) get extra attention
    case QtWarningMsg:
    case QtCriticalMsg:
    case QtFatalMsg:
        FilterQmlWarnings( context.file );
        break;

    default:
        FFAIL( "impossible. there are no other enum values to test for" );
    }
}

int QmlMessageInterceptor::TeeToSinks(
    QtMsgType type, const QMessageLogContext& context, const QString& message )
{
    if( m_threadId != std::this_thread::get_id() )
    {
        FFAIL( "TODO: do something smart if this happens. we must not call the tee(s) on "
               "background threads" );
        fprintf( stderr, "users were not expecting calls from a non-main/non-gui thread\n" );
        return 0;
    }

    int sinksThatWereLoggedTo = 0;
    for( auto& sink : m_sinks )
    {
        auto p = sink.lock();
        if( p && ( *p ) )
        {
            ( *p )( type, context, message );
            sinksThatWereLoggedTo++;
        }
    }
    CullDeadSinks();

    return sinksThatWereLoggedTo;
}

void QmlMessageInterceptor::CullDeadSinks()
{
    using weakPtr = std::weak_ptr<std::function<void(
        QtMsgType type, const QMessageLogContext& context, const QString& message )>>;
    m_sinks.erase( std::remove_if( m_sinks.begin(), m_sinks.end(),
                       []( weakPtr sinkPtr ) { return sinkPtr.expired(); } ),
        m_sinks.end() );
}

} // namespace heory
