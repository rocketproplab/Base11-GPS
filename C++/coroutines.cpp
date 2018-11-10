//////////////////////////////////////////////////////////////////////////
// Homemade GPS Receiver
// Copyright (C) 2013 Andrew Holme
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// http://www.aholme.co.uk/GPS/Main.htm
//////////////////////////////////////////////////////////////////////////

#include <setjmp.h>
#include <time.h>

#define STACK_SIZE 8192
#define MAX_TASKS 20

struct TASK {
    int stk[STACK_SIZE];
    union {
        jmp_buf jb;
        struct {
            void *v[6], *sl, *fp, *sp, (*pc)();
        };
    };
};

static TASK Tasks[MAX_TASKS];
static int NumTasks=1;
static unsigned Signals;

void NextTask() {
    static int id;
    if (setjmp(Tasks[id].jb)) return;
    if (++id==NumTasks) id=0;
    longjmp(Tasks[id].jb, 1);
}

void CreateTask(void (*entry)()) {
    TASK *t = Tasks + NumTasks++;
    t->pc = entry;
    t->sp = t->stk + STACK_SIZE-2;
}

unsigned Microseconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return ts.tv_sec*1000000 + ts.tv_nsec/1000;
}

void TimerWait(unsigned ms) {
    unsigned finish = Microseconds() + 1000*ms;
    for (;;) {
        NextTask();
        int diff = finish - Microseconds();
        if (diff<=0) break;
    }
}

void EventRaise(unsigned sigs) {
    Signals |= sigs;
}

unsigned EventCatch(unsigned sigs) {
    sigs &= Signals;
    Signals -= sigs;
    return sigs;
}
