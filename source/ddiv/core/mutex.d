/************************************************************************************************************************
It's internal code!
This module contain implementation of standard functionality.

Copyright: Copyright © 2018-2019, Dawid Masiukiewicz, Michał Masiukiewicz
License: BSD 3-clause, see LICENSE file in project root folder.

See: https://gitlab.com/Mergul/bubel-ecs/-/blob/master/source/bubel/ecs/std.d
*/
module ddiv.core.mutex;

version (Emscripten) version = ECSEmscripten;

import std.traits;

version (ECSEmscripten)
{
    extern (C) struct pthread_mutex_t
    {
        union
        {
            int[6] __i;
            void[6]* __p;
        }
    }

    extern (C) struct pthread_mutexattr_t
    {
        uint __attr;
    }

    extern (C) int pthread_mutex_lock(pthread_mutex_t* mutex) @nogc nothrow;
    extern (C) int pthread_mutex_trylock(pthread_mutex_t* mutex) @nogc nothrow;
    extern (C) int pthread_mutex_unlock(pthread_mutex_t* mutex) @nogc nothrow;
    extern (C) void pthread_mutexattr_settype(pthread_mutexattr_t* attr, int type) @nogc nothrow;
    extern (C) void pthread_mutexattr_destroy(pthread_mutexattr_t* attr) @nogc nothrow;
    extern (C) int pthread_mutexattr_init(pthread_mutexattr_t* attr) @nogc nothrow;
    extern (C) int pthread_mutex_destroy(pthread_mutex_t* mutex) @nogc nothrow;
    extern (C) int pthread_mutex_init(pthread_mutex_t* mutex, const pthread_mutexattr_t* attr) @nogc nothrow;

}

version (ECSEmscripten)
{
}
else version (Windows)
{
    import core.sys.windows.windows;
}
else version (Posix)
{
    import core.sys.posix.pthread;
}

/// Implement a native Mutex
struct Mutex
{

    version (ECSEmscripten)
    {
        void initialize() nothrow @nogc
        {
            pthread_mutexattr_t attr = void;

            //pthread_mutexattr_init(&attr);

            //pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
            pthread_mutex_init(cast(pthread_mutex_t*)&m_handle, &attr);

            //pthread_mutexattr_destroy(&attr);
        }

        void destroy() nothrow @nogc
        {
            pthread_mutex_destroy(&m_handle);
        }

        void lock() nothrow @nogc
        {
            pthread_mutex_lock(&m_handle);
        }

        void unlock() nothrow @nogc
        {
            pthread_mutex_unlock(&m_handle);
        }

        int tryLock() nothrow @nogc
        {
            return pthread_mutex_trylock(&m_handle) == 0;
        }

        private pthread_mutex_t m_handle;
    }
    else version (Windows)
    {
        void initialize() nothrow @nogc
        {
            InitializeCriticalSection(cast(CRITICAL_SECTION*)&m_handle);
        }

        void destroy() nothrow @nogc
        {
            DeleteCriticalSection(&m_handle);
        }

        void lock() nothrow @nogc
        {
            EnterCriticalSection(&m_handle);
        }

        void unlock() nothrow @nogc
        {
            LeaveCriticalSection(&m_handle);
        }

        int tryLock() nothrow @nogc
        {
            return TryEnterCriticalSection(&m_handle) != 0;
        }

        CRITICAL_SECTION m_handle;
    }
    else version (Posix)
    {
        /// Initialices the mutex
        void initialize() nothrow @nogc
        {
            pthread_mutexattr_t attr = void;

            pthread_mutexattr_init(&attr);

            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
            pthread_mutex_init(cast(pthread_mutex_t*)&m_handle, &attr);

            pthread_mutexattr_destroy(&attr);
        }

        /// Destroys the mutex
        void destroy() nothrow @nogc
        {
            pthread_mutex_destroy(&m_handle);
        }

        /// Get a lock on the mutex
        void lock() nothrow @nogc
        {
            pthread_mutex_lock(&m_handle);
        }

        /// Releases the mutex
        void unlock() nothrow @nogc
        {
            pthread_mutex_unlock(&m_handle);
        }

        /// Try to lock the mutex and returns true if it's sucessful
        int tryLock() nothrow @nogc
        {
            return pthread_mutex_trylock(&m_handle) == 0;
        }

        private pthread_mutex_t m_handle;
    }
    else {
        static assert(0, "unsupported platform!");
    }
}
