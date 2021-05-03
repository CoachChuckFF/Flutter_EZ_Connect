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
// 
// Flutter Code
// 
// BlizzardEZConnectManager _manager = BlizzardEZConnectManager({params});
// 
// _manager.run(pass, {params});
// _manager.cancel();
// _manager.dispose();
// 
// 

class BlizzardEZConnectResult {
  final String ip;
  final String bssid;
  final int devicesLeft;
  final int totalDevices;

  BlizzardEZConnectResult({
    this.ip,
    this.bssid,
    this.totalDevices,
    this.devicesLeft,
  });

  int get deviceIndex {
    return totalDevices - devicesLeft - 1;
  }

  int get deviceNumber {
    return totalDevices - devicesLeft;
  }

  factory BlizzardEZConnectResult.fromESP(ESPTouchResult data, int totalDevices, int devicesLeft){
    return BlizzardEZConnectResult(
      ip: data.ip ?? "",
      bssid: data.bssid ?? "",
      totalDevices: totalDevices,
      devicesLeft: devicesLeft,
    );
  }

  @override
  String toString() {
    String string = "";

    string += "\n---------- EZ Connect -----------\n"; 
    string += "Status: ${this.ip.isNotEmpty ? 'SUCCESS' : 'FAIL'}\n"; 
    string += "IP: ${this.ip}\n"; 
    string += "BSSID: ${this.bssid}\n"; 
    string += "Devices Left: ${this.bssid}\n"; 
    string += "---------------------------------\n\n"; 

    return string;
  }

}

class BlizzardEZConnectManager {
  final String _superSecretObscureSSIDString = "B";
  final String _superSecretObscurePASSString = "L";

  final Duration timeoutDuration;
  final Function(String, String) onStart;
  final Function onCancel;
  final Function onTimeout;
  final Function onSuccess;
  final Function(BlizzardEZConnectResult) onConnected;

  BlizzardEZConnectManager({
    this.timeoutDuration,
    this.onStart,
    this.onCancel,
    this.onTimeout,
    this.onConnected,
    this.onSuccess,
  });

  StreamSubscription<ESPTouchResult> _ezConnectController;
  Timer _ezConnectWatchdog;

  bool isRunning = false;
  int deviceCount = 1;
  int devicesLeft = 1;

  void cancel(){
    _stopEZConnect();
    if(onCancel != null) onCancel();
  }

  void dispose(){
    _stopEZConnect();
  }

  Future<void> run(
    String pass,
    {
      String ssid, //await getCurrentSSID();
      String bssid, //await getCurrentBSSID();
      int deviceCount = 1, 
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

    this.deviceCount = deviceCount;
    this.devicesLeft = deviceCount;

    //config EZConnect
    task = ESPTouchTask(ssid: ssid + _superSecretObscureSSIDString, bssid: bssid, password: pass + _superSecretObscurePASSString);

    //start EZConnect
    stream = task.execute();

    //listen to EZConnect
    _ezConnectController = stream.listen((result){
      devicesLeft--;
      if(onConnected != null) onConnected(BlizzardEZConnectResult.fromESP(result, deviceCount, devicesLeft));

      if(devicesLeft <= 0){
        if(onSuccess != null) onSuccess();
        _stopEZConnect();
      } else {
        if(_ezConnectWatchdog.isActive) _ezConnectWatchdog.cancel();
        _ezConnectWatchdog = Timer(timeoutDuration ?? Duration(seconds: 90), _setWatchdog);
      }
    });

    //set timeout EZConnect
    _ezConnectWatchdog = Timer(timeoutDuration ?? Duration(seconds: 90), _setWatchdog);

    //finish starting the task
    if(onStart != null) onStart(ssid, bssid);

    isRunning = true;
  }

  void _setWatchdog(){
    _stopEZConnect();
    if(onTimeout != null) onTimeout();
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
