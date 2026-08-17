#include <mach/cthreads.h>

static any_t worker(any_t argument)
{
    mutex_t mutex = (mutex_t)argument;

    mutex_lock(mutex);
    mutex_unlock(mutex);
    return argument;
}

int main(void)
{
    cthread_t thread;
    mutex_t mutex;
    any_t result;

    cthread_init();
    mutex = mutex_alloc();
    if (mutex == 0) {
        return 1;
    }
    mutex_init(mutex);
    thread = cthread_fork((cthread_fn_t)worker, (any_t)mutex);
    if (thread == NO_CTHREAD) {
        mutex_free(mutex);
        return 2;
    }
    result = cthread_join(thread);
    mutex_free(mutex);
    return result == (any_t)mutex ? 0 : 3;
}

