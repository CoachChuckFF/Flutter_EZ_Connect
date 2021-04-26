import 'dart:async';

import 'package:esptouch_flutter/esptouch_flutter.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

const hc_pass = 'destroyer';

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String buttonText = "Start";
  String resultText = 'Connect me daddy';
  bool canRun = true;


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


  void runEZConnect({
    @required String ssid, //await getCurrentSSID();
    @required String bssid, //await getCurrentBSSID();
    @required String pass,
    Duration timoutDuration,
    Function onTimeout,
    Function onStart,
    Function(ESPTouchResult) onConnected,
  }){
    Timer watchdog;
    StreamSubscription<ESPTouchResult> sub;
    Stream<ESPTouchResult> stream;
    ESPTouchTask task;
    
    //config EZConnect
    task = ESPTouchTask(ssid: ssid, bssid: bssid, password: pass);

    //start EZConnect
    stream = task.execute();

    //listen to EZConnect
    sub = stream.listen((result){
      watchdog.cancel();
      if(sub != null) sub.cancel();
      if(onConnected != null) onConnected(result);
    });

    //set timeout EZConnect
    watchdog = Timer(timoutDuration ?? Duration(seconds: 90), (){
      if(sub != null) sub.cancel();
      if(onTimeout != null) onTimeout();
    });

    //finish starting the task
    if(onStart != null) onStart();
  }


  Future<String> getCurrentSSID() async{
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

  Future<String> getCurrentBSSID() async{
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

  // //Example Usage
  // void exampleRunEZConnect() async{
  //   String ssid = await getCurrentSSID();
  //   String bssid = await getCurrentBSSID();

  //   runEZConnect(
  //     ssid: ssid,
  //     bssid: bssid,
  //     pass: hc_pass,
  //     onTimeout: (){
  //       print("Timeout");
  //       setState(() {
  //         canRun = true;
  //         buttonText = "Start";
  //         resultText = "Timeout";
  //       });
  //     },
  //     onConnected: (result){
  //       print("Connected: " + result.ip);
  //       setState(() {
  //         canRun = true;
  //         buttonText = "Start";
  //         resultText = "Connected!";
  //       });
  //     },
  //     onStart: (){
  //       print("Started");
  //       setState(() {
  //         canRun = false;
  //         buttonText = "Working";
  //         resultText = '$ssid | $bssid | $hc_pass';
  //       });
  //     }
  //   );
  // }

// ------------------------- End EZ Connect Code -----------------

  //Example Usage
  void exampleRunEZConnect() async{
    String ssid = await getCurrentSSID();
    String bssid = await getCurrentBSSID();

    runEZConnect(
      ssid: ssid,
      bssid: bssid,
      pass: hc_pass,
      onTimeout: (){
        print("Timeout");
        setState(() {
          canRun = true;
          buttonText = "Start";
          resultText = "Timeout";
        });
      },
      onConnected: (result){
        print("Connected: " + result.ip);
        setState(() {
          canRun = true;
          buttonText = "Start";
          resultText = "Connected!";
        });
      },
      onStart: (){
        print("Started");
        setState(() {
          canRun = false;
          buttonText = "Working";
          resultText = '$ssid | $bssid | $hc_pass';
        });
      }
    );
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Blizzard EZ Connect'),
              Container(height: 13,),
              Text(resultText),
              Container(height: 5,),
              OutlineButton(
                onPressed: (){
                  if(canRun) exampleRunEZConnect();
                },
                child: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}