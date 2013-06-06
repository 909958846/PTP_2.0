#include <inttypes.h>
#include <avr/pgmspace.h>

#include <avrpins.h>
#include <max3421e.h>
#include <usbhost.h>
#include <usb_ch9.h>
#include <Usb.h>
#include <usbhub.h>
#include <address.h>

#include <message.h>
#include <parsetools.h>

#include <ptp.h>
#include <canonps.h>
#include <qp_port.h>
#include <valuelist.h>
#include <psvaluetitles.h>

#include "ptpdpparser.h"
#include "ptpobjinfoparser.h"
#include "pseventparser.h"
#include "psconsole.h"

class CamStateHandlers : public PSStateHandlers
{
      enum CamStates { stInitial, stDisconnected, stConnected };
      CamStates stateConnected;
    
      uint32_t nextPollTime;
      
public:
      CamStateHandlers() : stateConnected(stInitial), nextPollTime(0)
      {
      };
      
      virtual void OnDeviceDisconnectedState(PTP *ptp);
      virtual void OnDeviceInitializedState(PTP *ptp);
};

CamStateHandlers  CamStates;

USB                 Usb;
//USBHub              Hub1(&Usb);
CanonPS             Ps(&Usb, &CamStates);

QEvent            evtTick; //, evtAbort;
PSConsole         psConsole;

void CamStateHandlers::OnDeviceDisconnectedState(PTP *ptp)
{
    if (stateConnected == stConnected || stateConnected == stInitial)
    {
        stateConnected = stDisconnected;
        Notify(PSTR("Camera disconnected.\r\n"),0x80);
        
        if (stateConnected == stConnected)
            psConsole.dispatch(&evtTick);
    }
}

void CamStateHandlers::OnDeviceInitializedState(PTP *ptp)
{
    if (stateConnected == stDisconnected || stateConnected == stInitial)
    {
        stateConnected = stConnected;
        Notify(PSTR("Camera connected.\r\n"),0x80);
        psConsole.dispatch(&evtTick);
    }
    int8_t  index = psConsole.MenuSelect();
    
    if (index >= 0)
    {
        MenuSelectEvt     menu_sel_evt;
        menu_sel_evt.sig         = MENU_SELECT_SIG;
        menu_sel_evt.item_index  = index;
        psConsole.dispatch(&menu_sel_evt);      // dispatch the event
    }
    uint32_t time_now = millis();
    
    if (time_now >= nextPollTime)
    {
        nextPollTime = time_now + 300;
        
        PSEventParser  prs;
        Ps.EventCheck(&prs);
        
        if (uint32_t handle = prs.GetObjHandle())
        {
                    PTPObjInfoParser     inf;
                    Ps.GetObjectInfo(handle, &inf);
        }
    }
}

void setup()
{
    Serial.begin(115200);

    if (Usb.Init() == -1)
        Serial.println("OSC did not start.");

    delay( 200 );
  
    evtTick.sig = TICK_SIG;
//    evtAbort.sig = ABORT_SIG;
    psConsole.init();

    Serial.println("Start");
}

void loop()
{
    Usb.Task();
}
 
