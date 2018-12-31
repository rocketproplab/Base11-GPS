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
#include <stdio.h>

#define STACK_SIZE 8192
#define MAX_TASKS 20
#define SETJMP_OFFSET 0x14

struct TASK {
        int stk[STACK_SIZE];
        union {
                jmp_buf jb;
                struct {
                        void *v[6], *sl, *fp, *sp, (*pc)();
                };
        };
};

static struct TASK seceret;
static unsigned long seceretKey;

unsigned long rotateRight(unsigned long x, int n){

        // if n=4, x=0x12345678:

        // shifted = 0x12345678 >> 4 = 0x01234567
        unsigned long shifted  = x >> n;

        // rot_bits = (0x12345678 << 28) = 0x80000000
        unsigned long rot_bits = x << ( 32 - n );

        // combined = 0x80000000 | 0x01234567 = 0x81234567
        unsigned long combined = shifted | rot_bits;

        return combined;
}

void InitTasks(){
        setjmp(seceret.jb);
        printf("Size of long %d\n", sizeof(unsigned long));
        unsigned long pcMangle = (unsigned long) seceret.pc;
        unsigned long pcActual =  (unsigned long) InitTasks + SETJMP_OFFSET;
        // pcMangle   = rotateRight(pcMangle, 2 * 8 + 1);
        seceretKey = ((unsigned long )pcMangle) ^ pcActual;
}

unsigned long _rotl(unsigned long value, int shift){
        if(( shift &= sizeof( value ) * 8 - 1 ) == 0)
                return value;
        return ( value << shift ) | ( value >> ( sizeof( value ) * 8 - shift ));
}

unsigned long convertToSeceret(void *pc){
        unsigned long mangled = ((unsigned long) pc ) ^ seceretKey;
        // unsigned long shifted = _rotl((unsigned long) mangled, 2 * 8 + 1);
        return mangled;
}

unsigned long convertFromMangled(void *mangled){
        // unsigned long mangled = rotateRight((unsigned long) shifted, 2 * 8 + 1);
        return ((unsigned long)mangled) ^ seceretKey;
}

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
        t->pc = (void (*)())convertToSeceret((void *)entry);
        int* stackStart = t->stk + STACK_SIZE-2;
        t->sp = (void *) convertToSeceret((void *)stackStart);
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
        printf("Got event %d\n", sigs);
        Signals |= sigs;
}

unsigned EventCatch(unsigned sigs) {
        sigs &= Signals;
        Signals -= sigs;
        return sigs;
}
