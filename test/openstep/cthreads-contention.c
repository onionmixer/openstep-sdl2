#include <mach/cthreads.h>

#define WORKER_COUNT 4
#define INCREMENTS_PER_WORKER 10000

static mutex_t state_mutex;
static condition_t state_condition;
static int ready_workers;
static int start_workers;
static int counter;

static any_t worker(any_t unused)
{
    int index;

    (void)unused;
    mutex_lock(state_mutex);
    ++ready_workers;
    condition_signal(state_condition);
    while (!start_workers) {
        condition_wait(state_condition, state_mutex);
    }
    mutex_unlock(state_mutex);

    for (index = 0; index < INCREMENTS_PER_WORKER; ++index) {
        mutex_lock(state_mutex);
        ++counter;
        mutex_unlock(state_mutex);
    }
    return (any_t)0;
}

int main(void)
{
    cthread_t workers[WORKER_COUNT];
    int index;

    cthread_init();
    state_mutex = mutex_alloc();
    state_condition = condition_alloc();
    if (state_mutex == 0 || state_condition == 0) {
        return 1;
    }
    mutex_init(state_mutex);
    condition_init(state_condition);

    for (index = 0; index < WORKER_COUNT; ++index) {
        workers[index] = cthread_fork((cthread_fn_t)worker, (any_t)0);
        if (workers[index] == NO_CTHREAD) {
            return 2;
        }
    }

    mutex_lock(state_mutex);
    while (ready_workers != WORKER_COUNT) {
        condition_wait(state_condition, state_mutex);
    }
    start_workers = 1;
    condition_broadcast(state_condition);
    mutex_unlock(state_mutex);

    for (index = 0; index < WORKER_COUNT; ++index) {
        cthread_join(workers[index]);
    }
    condition_free(state_condition);
    mutex_free(state_mutex);
    return counter == (WORKER_COUNT * INCREMENTS_PER_WORKER) ? 0 : 3;
}

