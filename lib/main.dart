import 'dart:async';

import 'package:esptouch_flutter/esptouch_flutter.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'blizzard_ez_connect_manager.dart';
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
  TextEditingController _passwordController = TextEditingController(text: hc_pass);
  FocusNode _passwordFocus = FocusNode();
  BlizzardEZConnectManager _ezConnectManager;
  String _messageText = 'Connect me daddy';
  String _buttonText = "Start";
  int _deviceCount = 1;

  @override
  void initState() {
  
    _ezConnectManager = BlizzardEZConnectManager(
      onStart: (ssid, bssid){
        setState(() {
          _messageText = "Connecting: $_deviceCount devices";
          _buttonText = "Working";
        });
      },
      onCancel: (){
        setState(() {
          _messageText = "Cancelled";
          _buttonText = "Start";
        });
      },
      onTimeout: (){
        setState(() {
          _messageText = "Timeout";
          _buttonText = "Start";
        });
      },
      onConnected: (result){
        setState(() {
          _messageText = "Connected! ${result.deviceNumber} out of ${result.totalDevices}";
          _buttonText = "Working";
        });
      },
      onSuccess: (){
        setState(() {
          _messageText = "All devices connected!";
          _buttonText = "Start";
        });
      }
    );

    super.initState();
  }


  @override
  void dispose() {
    //Remeber to dispose
    _ezConnectManager.dispose();

    _passwordFocus.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: (){
            _passwordFocus.unfocus();
          },
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Blizzard EZ Connect'),
                  Container(height: 13,),
                  Text(_messageText),
                  Container(
                    padding: EdgeInsets.fromLTRB(21, 13, 55, 13),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.lock,
                            size: 34,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            child: TextField(
                              focusNode: _passwordFocus,
                              controller: _passwordController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Password',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(50, 0, 50, 0),
                    height: 80,
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: (){
                            setState(() {
                              if(_deviceCount > 1) _deviceCount--;
                            });
                          },
                          child: Text(
                            '-',
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Devices: $_deviceCount',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: (){
                            setState(() {
                              if(_deviceCount < 10) _deviceCount++;
                            });
                          },
                          child: Text(
                            '+',
                          ),
                        ),
                      ]
                    ),
                  ),
                  OutlinedButton(
                    onPressed: (){
                      _ezConnectManager.runEZConnect(_passwordController.text, deviceCount: _deviceCount);
                    },
                    onLongPress: (){
                      _ezConnectManager.cancelEZConnect();
                    },
                    child: Text(
                      _buttonText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}