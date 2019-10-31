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

#include <stdlib.h>
#include <unistd.h>     // UNIX standard function definitions
#include <fcntl.h>      // File control definitions
#include <errno.h>      // Error number definitions
#include <termios.h>    // POSIX terminal control definitions
#include <iostream>

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
};

struct GPSDebug {
  int sVCount;
  double accuracy;
};

static struct GPSInfo UserState = {0};
static struct GPSDebug UserDbg = {0};

static int USB = 0;

///////////////////////////////////////////////////////////////////////////////////////////////

//From https://stackoverflow.com/questions/18108932/linux-c-serial-port-reading-writing
void initUser(){
  USB = open( "/dev/ttyUSB0", O_RDWR| O_NOCTTY );

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
int computeChecksum(char *sentence);

void sendSentence(char * sentence ){
  int checksum = computeChecksum(sentence);
  int len = strlen(sentence);
  sprintf(sentence + len, "*%02x\n", checksum);

  int n_written = 0,
      spot = 0;
  do {
      n_written = write( USB, &sentence[spot], 1 );
      spot += n_written;
  } while (sentence[spot-1] != '\n' && n_written > 0);
}

int computeChecksum(char *sentence){
  int checksum = 0;
  int len = strlen(sentence);
  for(int i = 0; i<len; i++){
    checksum ^= sentence[i];
  }

  return checksum;
}

///////////////////////////////////////////////////////////////////////////////////////////////

void sendGGA(){
  char buff[BUFSIZ];
  char *pbuff =  buff;
  pbuff += sprintf(pbuff, "$GPGGA,");               //MSG ID
  pbuff += sprintf(pbuff, "%d,", UserState.t_b);    //UTC
  pbuff += sprintf(pbuff, "%d,", UserState.lat);    //Lat
  pbuff += sprintf(pbuff, "N,");                    //N,S
  pbuff += sprintf(pbuff, "%d,", UserState.lon);    //Long
  pbuff += sprintf(pbuff, "W,1,");                  //W/E, Qualiy
  pbuff += sprintf(pbuff, "%d,", UserDbg.sVCount);  //SV Count
  pbuff += sprintf(pbuff, "1.2,");                  //DOP
  pbuff += sprintf(pbuff, "%d,", UserState.alt);    //Altitude
  pbuff += sprintf(pbuff, "M,");                    //Height Units
  pbuff += sprintf(pbuff, "%d,", UserDbg.accuracy); //Acurracy of GPS
  pbuff += sprintf(pbuff, "M,0,0");                 //Rest of non important data

  sendSentence(buff);

}


///////////////////////////////////////////////////////////////////////////////////////////////

void UserTask() {

    for(;;){
      if(UserState.update){
        sendGGA();
      }
      NextTask();
    }
}
