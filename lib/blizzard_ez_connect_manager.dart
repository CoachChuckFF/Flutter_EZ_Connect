import 'dart:async';

import 'package:esptouch_flutter/esptouch_flutter.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';

// ------------------------- EZ Connect Code -----------------
// All the code needed to run this in @Full
// 
// XCODE
// On Target > Runner > Signing & Capabilities, use the + Capability button to add the Access WiFi Information capability to your project.
// 
// INFO.PLIST
// **** <project root>/ios/Runner/Info.plist ****
// <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
// <string>Location is ONLY used to grab your SSID name, nothing else</string>
// <key>NSLocationWhenInUseUsageDescription</key>
// <string>Location is ONLY used to grab your SSID name, nothing else</string>
// 
// PUBSPEC YAML
// esptouch_flutter: ^0.2.4
// wifi_info_flutter: ^2.0.0
// 
// IMPORTS
// import 'dart:io'; //Needed for Platform
// import 'package:esptouch_flutter/esptouch_flutter.dart';
// import 'package:wifi_info_flutter/wifi_info_flutter.dart';
// 
// LINKS
// Getting SSID, BSSID
// https://pub.dev/packages/wifi_info_flutter
// https://stackoverflow.com/questions/55716751/flutter-ios-reading-wifi-name-using-the-connectivity-or-wifi-plugin/55732656#55732656
// 
// ESP Touch
// https://pub.dev/packages/esptouch_flutter
// 
// 
// 
// 
// 
// OPERATION
// 
// On SoC-It start, if no SSID is found in storage - it will start EZ connect (Assuming SoC-It is in STA mode)
// SoC-It will now default to STA mode, therefore, all new SoC-Its will start in EZ connect
// 
// When SoC-It is trying to EZ connect it will flash fast green, when you see this, runEZConnect()
// 
// Once a connection is established EZ connect will disable - until the SSID stored in the SoC-It is cleared
// 
// To re-establish a connection:
// NVS_CONFIG SSID = ""
// NVS_CONNECTION = External (STA)
// Reboot SoC-It
// 

class BlizzardEZConnectResult {
  final String ip;
  final String bssid;

  BlizzardEZConnectResult({
    this.ip,
    this.bssid,
  });

  factory BlizzardEZConnectResult.fromESP(ESPTouchResult data){
    return BlizzardEZConnectResult(
      ip: data.ip ?? "",
      bssid: data.bssid ?? "",
    );
  }

  @override
  String toString() {
    String string = "";

    string += "\n---------- EZ Connect -----------\n"; 
    string += "Status: ${this.ip.isNotEmpty ? 'SUCCESS' : 'FAIL'}\n"; 
    string += "IP: ${this.ip}\n"; 
    string += "BSSID: ${this.bssid}\n"; 
    string += "---------------------------------\n\n"; 

    return string;
  }

}

class BlizzardEZConnectManager {
  final Duration timeoutDuration;
  final Function(String, String) onStart;
  final Function onCancel;
  final Function onTimeout;
  final Function(BlizzardEZConnectResult) onConnected;

  BlizzardEZConnectManager({
    this.timeoutDuration,
    this.onStart,
    this.onCancel,
    this.onTimeout,
    this.onConnected,
  });

  bool isRunning = false;
  StreamSubscription<ESPTouchResult> _ezConnectController;
  Timer _ezConnectWatchdog;

  Future<void> runEZConnect(
    String pass,
    {
      String ssid, //await getCurrentSSID();
      String bssid, //await getCurrentBSSID();
  }) async {
    Stream<ESPTouchResult> stream;
    ESPTouchTask task;
    
    if(isRunning){
      print("EZ Connect Already Running");
      return;
    }

    if(ssid == null){
      ssid = await BlizzardEZConnectManager.getCurrentSSID();
    }
    if(bssid == null){
      bssid = await BlizzardEZConnectManager.getCurrentBSSID();
    }

    //config EZConnect
    task = ESPTouchTask(ssid: ssid, bssid: bssid, password: pass);

    //start EZConnect
    stream = task.execute();

    //listen to EZConnect
    _ezConnectController = stream.listen((result){
      _stopEZConnect();
      if(onConnected != null) onConnected(BlizzardEZConnectResult.fromESP(result));
    });

    //set timeout EZConnect
    _ezConnectWatchdog = Timer(timeoutDuration ?? Duration(seconds: 90), (){
      _stopEZConnect();
      if(onTimeout != null) onTimeout();
    });

    //finish starting the task
    if(onStart != null) onStart(ssid, bssid);

    isRunning = true;
  }

  void cancelEZConnect(){
    _stopEZConnect();
    if(onCancel != null) onCancel();
  }

  void dispose(){
    _stopEZConnect();
  }

  void _stopEZConnect(){
    if(_ezConnectController != null){
      _ezConnectController.cancel();
      _ezConnectController = null;
    }

    if(_ezConnectWatchdog != null){
      _ezConnectWatchdog.cancel();
      _ezConnectWatchdog = null;
    }

    isRunning = false;
  }

  // ----------------------- GETTERS FOR SSID AND BSSID --------------------------------------
  static Future<String> getCurrentSSID() async{
    if (Platform.isIOS) {
      LocationAuthorizationStatus status = await WifiInfo().getLocationServiceAuthorization();
      if (status == LocationAuthorizationStatus.authorizedAlways || status == LocationAuthorizationStatus.authorizedWhenInUse) {
        return WifiInfo().getWifiName();
      } else {
        await WifiInfo().requestLocationServiceAuthorization();
        LocationAuthorizationStatus status = await WifiInfo().getLocationServiceAuthorization();
        if (status == LocationAuthorizationStatus.authorizedAlways || status == LocationAuthorizationStatus.authorizedWhenInUse) {
          return WifiInfo().getWifiName();
        } else {
          print('Get SSID ERROR: Not Authed');
          return '';
        }
      }
    } else {
      return WifiInfo().getWifiName();
    }
  }

  static Future<String> getCurrentBSSID() async{
    if (Platform.isIOS) {
      LocationAuthorizationStatus status = await WifiInfo().getLocationServiceAuthorization();
      if (status == LocationAuthorizationStatus.authorizedAlways || status == LocationAuthorizationStatus.authorizedWhenInUse) {
        return WifiInfo().getWifiBSSID();
      } else {
        await WifiInfo().requestLocationServiceAuthorization();
        LocationAuthorizationStatus status = await WifiInfo().getLocationServiceAuthorization();
        if (status == LocationAuthorizationStatus.authorizedAlways || status == LocationAuthorizationStatus.authorizedWhenInUse) {
          return WifiInfo().getWifiBSSID();
        } else {
          print('Get BSSID ERROR: Not Authed');
          return '';
        }
      }
    } else {
      return WifiInfo().getWifiBSSID();
    }
  }
}
