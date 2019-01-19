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

#include <inttypes.h>

#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))

///////////////////////////////////////////////////////////////////////////////
// Parameters

#define FFT_LEN  40000
#define NUM_SATS    32
#define NUM_CHANS   12

///////////////////////////////////////////////////////////////////////////////
// Frequencies

#define L1 1575.42e6 // L1 carrier
#define FC 2.6e6     // Carrier @ 2nd IF
#define FS 10e6      // Sampling rate
#define CPS 1.023e6  // Chip rate
#define BPS 50.0     // NAV data rate

///////////////////////////////////////////////////////////////////////////////
// Official GPS constants

const double PI = 3.1415926535898;

const double MU = 3.986005e14;          // WGS 84: earth's gravitational constant for GPS user
const double OMEGA_E = 7.2921151467e-5; // WGS 84: earth's rotation rate

const double C = 2.99792458e8; // Speed of light

const double F = -4.442807633e-10; // -2*sqrt(MU)/pow(C,2)

//////////////////////////////////////////////////////////////
// Events

#define JOY_MASK 0x1F

#define JOY_RIGHT    (1<<0)
#define JOY_LEFT     (1<<1)
#define JOY_DOWN     (1<<2)
#define JOY_UP       (1<<3)
#define JOY_PUSH     (1<<4)
#define EVT_EXIT     (1<<5)
#define EVT_BARS     (1<<6)
#define EVT_POS      (1<<7)
#define EVT_TIME     (1<<8)
#define EVT_PRN      (1<<9)
#define EVT_SHUTDOWN (1<<10)

//////////////////////////////////////////////////////////////
// Coroutines

void InitTasks();

unsigned EventCatch(unsigned);
void     EventRaise(unsigned);
void     NextTask();
void     CreateTask(void (*entry)());
unsigned Microseconds(void);
void     TimerWait(unsigned ms);

//////////////////////////////////////////////////////////////
// BCM2835 peripherals

enum SPI_SEL {
    SPI_CS0=0,  // Load embedded CPU image
    SPI_CS1=1   // Host messaging
};

int  peri_init();
void peri_free();
void peri_spi(SPI_SEL sel, char *mosi, int txlen, char *miso, int rxlen);

//////////////////////////////////////////////////////////////
// Search

int  SearchInit();
void SearchFree();
void SearchTask();
void SearchEnable(int sv);
int  SearchCode(int sv, unsigned int g1);

//////////////////////////////////////////////////////////////
// Tracking

void ChanTask(void);
int  ChanReset(void);
void ChanStart(int ch, int sv, int t_sample, int taps, int lo_shift, int ca_shift);
bool ChanSnapshot(int ch, uint16_t wpos, int *p_sv, int *p_bits, float *p_pwr);

//////////////////////////////////////////////////////////////
// Solution

void SolveTask();

//////////////////////////////////////////////////////////////
// User interface

enum STAT {
    STAT_PRN,
    STAT_POWER,
    STAT_LAT,
    STAT_LON,
    STAT_ALT,
    STAT_TIME
};

void UserTask();
void setGPSState(double x, double y, double z, double t_b, double lat, double lon, double alt);

// All the NEMA-0183 codes that are used
enum NEMACode {
  GGA,    //Global Positioning System Fix Data (This is the important one)
  GLL,    //Geographic position, latitude and longitude (and time)
  GSV,    //Satellites in view
  HDT,    //Heading, true north
  VTG,    //Track made good and ground speed
  XTE     //Cross-track error
}
