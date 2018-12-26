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

#include <unistd.h>
#include <stdio.h>
#include <math.h>

#include "Print.h"
#include "gps.h"
#include "spi.h"


///////////////////////////////////////////////////////////////////////////////////////////////

void Print::digitalWrite(int pin, int state) {

}

void Print::delayMicroseconds(int n) {
    if (n>1) usleep(n);
}



///////////////////////////////////////////////////////////////////////////////////////////////

struct UMS {
    int u, m;
    double s;
    UMS(double x) {
        u = trunc(x); x = (x-u)*60;
        m = trunc(x); s = (x-m)*60;
    }
};



///////////////////////////////////////////////////////////////////////////////////////////////

void UserTask() {
    // DISPLAY lcd;
    // int page=0;
    //
    // lcd.drawForm(-2);
    // for (int i=0; i<30; i++) {
    //     TimerWait(100);
    //     if (EventCatch(JOY_MASK)) {
    //         EventRaise(EVT_EXIT);
    //         for (;;) NextTask();
    //     }
    // }
    // lcd.drawForm(page);
    // for (;;) {
    //     switch (EventCatch(JOY_MASK)) {
    //         case JOY_UP:
    //             if (page>0) lcd.drawForm(--page);
    //             break;
    //         case JOY_DOWN:
    //             if (page<3) lcd.drawForm(++page);
    //             break;
    //         case JOY_PUSH:
    //             lcd.drawForm(-1);
    //             EventRaise(EVT_EXIT+EVT_SHUTDOWN);
    //             for (;;) NextTask();
    //
    //     }
    //     lcd.drawData(page);
    //     NextTask();
    // }
}
