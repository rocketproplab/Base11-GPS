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

#include <unistd.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

#include "Print.h"
#include "gps.h"
#include "spi.h"

#define EQUALS_EPSILON 0.0000001
#define GPS_ID "GP"
#define GPS_ID_LEN 2
#define NEMA_DELIM ","

struct GPSInfo {
  double x, y, z, t_b, lat, lon, alt;
  bool update;
}

static struct GPSInfo UserState = {0};

static int USB = 0;

///////////////////////////////////////////////////////////////////////////////////////////////

//From https://stackoverflow.com/questions/18108932/linux-c-serial-port-reading-writing
void initUser(){
  int USB = open( "/dev/ttyUSB0", O_RDWR| O_NOCTTY );

  struct termios tty;
  struct termios tty_old;
  memset (&tty, 0, sizeof tty);

  /* Error Handling */
  if ( tcgetattr ( USB, &tty ) != 0 ) {
     std::cout << "Error " << errno << " from tcgetattr: " << strerror(errno) << std::endl;
  }

  /* Save old tty parameters */
  tty_old = tty;

  /* Set Baud Rate */
  cfsetospeed (&tty, (speed_t)B9600);
  cfsetispeed (&tty, (speed_t)B9600);

  /* Setting other Port Stuff */
  tty.c_cflag     &=  ~PARENB;            // Make 8n1
  tty.c_cflag     &=  ~CSTOPB;
  tty.c_cflag     &=  ~CSIZE;
  tty.c_cflag     |=  CS8;

  tty.c_cflag     &=  ~CRTSCTS;           // no flow control
  tty.c_cc[VMIN]   =  1;                  // read doesn't block
  tty.c_cc[VTIME]  =  5;                  // 0.5 seconds read timeout
  tty.c_cflag     |=  CREAD | CLOCAL;     // turn on READ & ignore ctrl lines

  /* Make raw */
  cfmakeraw(&tty);

  /* Flush Port, then applies attributes */
  tcflush( USB, TCIFLUSH );
  if ( tcsetattr ( USB, TCSANOW, &tty ) != 0) {
     std::cout << "Error " << errno << " from tcsetattr" << std::endl;
  }
}

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

bool epsilonEquals(double val1, double val2){
  double diff = (val1 - val2);
  diff = diff > 0 ? diff : -diff;
  return  diff > EQUALS_EPSILON;
}

///////////////////////////////////////////////////////////////////////////////////////////////

//Set the GPS state to the new state, checks if there are actually any changes
void setGPSState(double x, double y, double z, double t_b, double lat, double lon, double alt){
  bool needsUpdate = !epsilonEquals(x, UserState.x);
  needsUpdate |= !epsilonEquals(y, UserState.y);
  needsUpdate |= !epsilonEquals(z, UserState.z);
  needsUpdate |= !epsilonEquals(t_b, UserState.t_b);
  needsUpdate |= !epsilonEquals(lat, UserState.lat);
  needsUpdate |= !epsilonEquals(lon, UserState.lon);
  needsUpdate |= !epsilonEquals(alt, UserState.alt);

  if(needsUpdate){
    UserState = {x, y, z, t_b, lat, lon, alt, true};
  }

}

///////////////////////////////////////////////////////////////////////////////////////////////

void sendSentnece(char * sentence ){

}

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
    for(;;){
      if(UserState.update){

      }
    }
}
