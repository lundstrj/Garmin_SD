/*
  Garmin_sd - a data source for OpenSeizureDetector that runs on a
  Garmin ConnectIQ watch.

  See http://openseizuredetector.org for more information.

  Copyright Graham Jones, 2019.

  This file is part of Garmin_sd.

  Garmin_sd is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Garmin_sd is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Garmin_sd.  If not, see <http://www.gnu.org/licenses/>.

*/
using Toybox.Communications as Comm;
using Toybox.Attention as Attention;

class GarminSDComms {
  var listener;
  var mAccelHandler = null;
  var lastOnReceiveResponse = -1;
  var lastOnReceiveData = "";
  var lastOnSdStatusReceiveResponse = -1;
  //var serverUrl = "http:192.168.43.1:8080";
  var serverUrl = "http://127.0.0.1:8080";

  function initialize(accelHandler) {
    listener = new CommListener();
    mAccelHandler = accelHandler;
  }

  function onStart() {
    // We use http communications not phone app messages.
    //Comm.registerForPhoneAppMessages(method(:onMessageReceived));
    //Comm.transmit("Hello World.", null, listener);

  }

  function sendAccelData() {
    var dataObj = mAccelHandler.getDataJson();
    
    Comm.makeWebRequest(
			serverUrl+"/data",
			{"dataObj"=>dataObj},
			{
			  :method => Communications.HTTP_REQUEST_METHOD_POST,
			    :headers => {
			    "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
			  }
			},
			method(:onReceive));
  }

  function sendSettings() {
    var dataObj = mAccelHandler.getSettingsJson();
    //System.println("sendSettings() - dataObj="+dataObj);
    Comm.makeWebRequest(
			serverUrl+"/settings",
			{"dataObj"=>dataObj},
			{
			  :method => Communications.HTTP_REQUEST_METHOD_POST,
			    :headers => {
			    "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
			  }
			},
			method(:onReceive));    
  }

  function getSdStatus() {
    // System.println("getSdStatus()");
    Comm.makeWebRequest(
			serverUrl+"/data",
			{ },
			{
			  :method => Communications.HTTP_REQUEST_METHOD_GET,
			    :headers => {                                    
			    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED },
			    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON	
			       },
			method(:onSdStatusReceive)
      );
    //System.println("getSdStatus Exiting");
  }


  // Receive the data from the web request - should be a json string
  function onSdStatusReceive(responseCode, data) {
    //System.println("onSdStatusReceive - ResponseCode="+responseCode);
    if (responseCode == 200) {
      if (responseCode != lastOnSdStatusReceiveResponse) {
	System.println("onSdStatusReceive() success - data ="+data);
	System.println("onSdStatusReceive() Status ="+data.get("alarmPhrase"));
      }
      mAccelHandler.mStatusStr = data.get("alarmPhrase");
      if (data.get("alarmState") != 0) {
	try {
	  if (Attention has :backlight) {
	    Attention.backlight(true);
	  }
	} catch( ex ) {
	  // We might get a Toybox.Attention.BacklightOnTooLongException
	}
	if (Attention has :playTone) {
	  Attention.playTone(Attention.TONE_ALERT_HI);
	}
      }
      if (data.get("alarmState") == 2) { // ALARM
	if (Attention has :vibrate) {
	  var vibeData =
	    [
	     new Attention.VibeProfile(50, 500),
	     new Attention.VibeProfile(0, 500),  
	     new Attention.VibeProfile(50, 500), 
	     new Attention.VibeProfile(0, 500),  
	     new Attention.VibeProfile(50, 500)  
	     ];
	  Attention.vibrate(vibeData);
	}
      }
    } else {
      mAccelHandler.mStatusStr = Rez.Strings.Error_abbrev + ": " + responseCode.toString();
      if (responseCode != lastOnSdStatusReceiveResponse) {
	System.println("onSdStatusReceive() Failue - code =");
	System.println(responseCode);
	System.println("onSdStatusReceive() Failure - data ="+data);
      } else {
	System.print(".");
      }
    }
    lastOnSdStatusReceiveResponse = responseCode;
  }

  
  // Receive the response from the sendAccelData or sendSettings web request.
  function onReceive(responseCode, data) {
    if (responseCode == 200) {
      if ((responseCode != lastOnReceiveResponse) || (data != lastOnReceiveData) ) {	
	System.println("onReceive() success - data ="+data);
      } else {
	System.print(".");
      }
      if (data.equals("sendSettings")) {
	//System.println("Sending Settings");
	sendSettings();
      } else {
	//System.println("getting sd status");
	getSdStatus();
      }
    } else {
      mAccelHandler.mStatusStr = "ERR: " + responseCode.toString();
      if (Attention has :playTone) {
	Attention.playTone(Attention.TONE_LOUD_BEEP);
      }
      if (Attention has :vibrate) {
	 var vibeData =
	  [
	   new Attention.VibeProfile(50, 200),
	   new Attention.VibeProfile(0, 200),  
	   new Attention.VibeProfile(50, 200), 
	   new Attention.VibeProfile(0, 200),  
	   new Attention.VibeProfile(50, 200)  
	   ];
	 Attention.vibrate(vibeData);
      }


      if (responseCode != lastOnReceiveResponse) {
	System.println("onReceive() Failue - code =");
	System.println(responseCode);
      } else {
	System.print(".");
      }
    }
    lastOnReceiveResponse = responseCode;
    lastOnReceiveData = data;
  }
  


  function onMessageReceived(msg) {
    var i;
    System.print("GarminSdApp.onMessageReceived - ");
    System.println(msg.data.toString());
  }
  
  /////////////////////////////////////////////////////////////////////
  // Connection listener class that is used to log success and failure
  // of message transmissions.
  class CommListener extends Comm.ConnectionListener {
    function initialize() {
      Comm.ConnectionListener.initialize();
    }
    
    function onComplete() {
      System.println("Transmit Complete");
    }
    
    function onError() {
      System.println("Transmit Failed");
    }
  }

}
