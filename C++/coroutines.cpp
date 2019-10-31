//////////////////////////////////////////////////////////////////////////
// Homemade GPS Receiver
// Copyright (C) 2018 Max Apodaca
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
// Original info found at http://www.aholme.co.uk/GPS/Main.htm
//////////////////////////////////////////////////////////////////////////

#include <setjmp.h>
#include <time.h>

#define STACK_SIZE 8192
#define MAX_TASKS 20
#define SETJMP_OFFSET 0x14
#define STACK_OFFSET 2

/**
 * Structure which stores the information about a task. This contains the stack
 * for each task which will be set in CreateTask. The union between the jmp_buf
 * and other struct allows accessing elements of the jmp_buf via discreet names.
 */
struct TASK {
        int stk[STACK_SIZE];
        union {
                jmp_buf jb;
                struct {
                        void *sp, (*pc)(), *v[6], *sl, *fp;
                };
        };
};

//the task to determin the seceret key, static to make offset calculation for
//InitTasks easier
static struct TASK seceret;

//The seceret key which is xored with all pointer used in jmp_buf
static unsigned long seceretKey;

/**
 * Determins the seceret key which will be used to mangle the pointers of the
 * jump buffer. It does this by calling setjump at the beginning of the function
 * which will set the pc of the jmp_buf to a know location (SETJMP_OFFSET from
 * the beginning of InitTasks()). To determin SETJMP_OFFSET run 'objdump -d' on
 * the resultant executable, then search for InitTasks and look for the index
 * of the instruction after the setjmp invocation. Then subtract this index
 * from that of the function.
 *
 * NOTE:  for x86 an extra rotate step is introduced by glibc for pointer
 *        mangleing that must be taken into account. See __longjmp.S for more
 *        information.
 *
 * Examples of the invocations for arm and x86.
 * Arm:
 *    18d54:	ebfff912  bl	171a4 <_setjmp@plt>
 * x86:
 *    829: e8 b2 fd ff ff     callq  5e0 <_setjmp@plt>
 */
void InitTasks(){
        setjmp(seceret.jb);
        unsigned long pcMangle = (unsigned long) seceret.pc;
        unsigned long pcActual =  (unsigned long) InitTasks + SETJMP_OFFSET;
        seceretKey = ((unsigned long )pcMangle) ^ pcActual;
}

/**
 * Coverts a pointer to the mangled version of the pointer. After InitTasks is
 * called this function becomes equivalent to the PTR_MANGLE2 macro in glibc.
 *
 * @param *pc the pointer to mangle
 * @return the mangled pointer
 */
unsigned long convertToSeceret(void *pc){
        unsigned long mangled = ((unsigned long) pc ) ^ seceretKey;
        return mangled;
}

/**
 * Converts the mangled pointer to its origional form, same as PTR_DEMANGLE2 in
 * glibc.
 *
 * @param *mangled the mangled pointer to demangle
 * @return the demangled pointer
 */
unsigned long convertFromMangled(void *mangled){
        return ((unsigned long)mangled) ^ seceretKey;
}

//Variables to keep track of tasks and flags set
static TASK Tasks[MAX_TASKS];
static int NumTasks=1;
static unsigned Signals;

/**
 * Starts the next task in the set of tasks. Will return once all other tasks
 * have called NextTask.
 *
 * This should be called when a task has to wait for something to happen and
 * should be called often.
 */
void NextTask() {
        static int id;
        if (setjmp(Tasks[id].jb)) {
                return;
        }
        if (++id==NumTasks) id=0;
        longjmp(Tasks[id].jb, 1);
}

/**
 * Creates a new task which will start by calling the function passed with an
 * empty stack. Note that functions passed into this function must never return.
 *
 * @param *entry the entry point into the task as a function, does not have to
 *        be the beginning of the function.
 */
void CreateTask(void (*entry)()) {
        TASK *task = Tasks + NumTasks++;

        task->pc = (void (*)())convertToSeceret((void *)entry);

        //We start at the end of the stack because the stack grows towards
        //smaller memory locations.
        int* stackStart = task->stk + STACK_SIZE-STACK_OFFSET;
        task->sp = (void *) convertToSeceret((void *)stackStart);
}

/**
 * determins the time in microseconds
 * @return the time in microseconds
 */
unsigned Microseconds(void) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        return ts.tv_sec*1000000 + ts.tv_nsec/1000;
}

/**
 * Waits for the specified length of time to pass, if there is time left to wait
 * other tasks will be executed. As a result ms is the minimum time but not the
 * maximum time which this function will wait.
 *
 * @param ms the time to wait
 */
void TimerWait(unsigned ms) {
        unsigned finish = Microseconds() + 1000*ms;
        for (;;) {
                NextTask();
                int diff = finish - Microseconds();
                if (diff<=0) break;
        }
}

/**
 * Sets the given event flag
 *
 * @param sigs the flags to set
 */
void EventRaise(unsigned sigs) {
        Signals |= sigs;
}

/**
 * Returns the if the given flags were set.
 *
 * @param sigs which flags to check
 * @reutrn the flags which were set and should have been checked
 */
unsigned int EventCatch(unsigned sigs) {
        sigs &= Signals;
        Signals -= sigs;
        return sigs;
}
