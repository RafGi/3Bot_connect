import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:threebotlogin/main.dart';
import 'package:threebotlogin/services/fingerprintService.dart';
import 'package:threebotlogin/widgets/ImageButton.dart';
import 'package:threebotlogin/widgets/PinField.dart';
import 'package:threebotlogin/services/userService.dart';
import 'package:threebotlogin/services/cryptoService.dart';
import 'package:threebotlogin/services/3botService.dart';
import 'package:threebotlogin/widgets/PreferenceDialog.dart';

class LoginScreen extends StatefulWidget {
  final Widget loginScreen;
  final Widget scopeList;
  final message;
  final bool closeWhenLoggedIn;

  LoginScreen(this.message,
      {Key key,
      this.loginScreen,
      this.closeWhenLoggedIn = false,
      this.scopeList})
      : super(key: key);

  _LoginScreenState createState() => _LoginScreenState();
}

Future<bool> _onWillPop() async {
  var index = 0;
  cancelLogin(await getDoubleName());
  for (var flutterWebViewPlugin in flutterWebViewPlugins) {
    if (flutterWebViewPlugin != null) {
      if (index == lastAppUsed) {
        flutterWebViewPlugin.show();
        showButton = true;
      }
      index++;
    }
  }
  return Future.value(true);
}

class _LoginScreenState extends State<LoginScreen> {
  String helperText = '';
  String scopeTextMobile =
      'Please select your preferred scopes and press Accept';
  String scopeText =
      'Please select your preferred scopes and press the corresponding emoji';
  List<int> imageList = new List();
  var selectedImageId = -1;
  var correctImage = -1;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var scope = Map();
  bool cancelBtnVisible = false;

  bool showPinfield = false;
  bool showScopeAndEmoji = false;
  bool isMobileCheck = false;

  @override
  void initState() {
    super.initState();
    isMobileCheck = checkMobile();

    makeScopes();

    var generated = 1;
    var rng = new Random();
    if (isNumeric(widget.message['randomImageId'])) {
      correctImage = int.parse(widget.message['randomImageId']);
    } else {
      correctImage = 1;
    }

    imageList.add(correctImage);

    while (generated <= 3) {
      var x = rng.nextInt(266) + 1;
      if (!imageList.contains(x)) {
        imageList.add(x);
        generated++;
      }
    }

    if (Platform.isIOS) {
      goToPinfield();
      checkFingerPrintActive();
    } else {
      checkFingerPrintActive();
    }

    print("====================");
    print("I only get here once");
    print("--------------------");

    setState(() {
      imageList.shuffle();
    });
  }

  checkFingerPrintActive() async {
    bool isValue = await getFingerprint();
    print("How many times do we get here");

    if (isValue) {
      bool isAuthenticate = await authenticate();
      print("How many times");
      print(isAuthenticate);

      if (isAuthenticate) {
        // Show scopes + emmoji
        print('inside authenticate');
        return finishLogin();
      }
    }
    // Show Pinfield
    goToPinfield();
  }

  void goToPinfield() {
    print('====================');
    print('showing pinfield');
    setState(() {
      helperText = 'Enter your pincode to log in';
      showPinfield = true;
      cancelBtnVisible = true;
    });
  }

  bool isRequired(value, givenScope) {
    bool flag = false;

    if (jsonDecode(givenScope)[value] != null &&
        jsonDecode(givenScope)[value]) {
      flag = true;
    }

    return flag;
  }

  makePermissionPrefs() async {
    if (await getScopePermissions() == null) {
      saveScopePermissions(jsonEncode(HashMap()));
    }

    var initialPermissions = jsonDecode(await getScopePermissions());
    print('initialpermissions: $initialPermissions');

    if (!initialPermissions.containsKey(widget.message['appId'])) {
      print('Permissions for this appId not found in prefs');
      var newHashMap = new HashMap();
      initialPermissions[widget.message['appId']] = newHashMap;

      if (scope != null) {
        scope.keys.toList().forEach((var value) {
          newHashMap[value] = {
            'enabled': true,
            'required': isRequired(value, widget.message['scope'])
          };
        });
      }
      print('setting perm $initialPermissions');
      saveScopePermissions(jsonEncode(initialPermissions));
    } else {
      print('Permissions already in prefs');
      var arr = ['doubleName', 'email', 'derivedSeed'];

      arr.forEach((var value) {
        if (!initialPermissions[widget.message['appId']].containsKey(value)) {
          print('$scope $value  ${!scope.keys.toList().contains(value)}');
          initialPermissions[widget.message['appId']][value] = {
            'enabled': true,
            'required': isRequired(value, widget.message['scope'])
          };
        }
      });
      print('setting perm $initialPermissions');
      saveScopePermissions(jsonEncode(initialPermissions));
    }
  }

  void makeScopes() async {
    print('widget ${widget.message['scope']}');
    if (widget.message['scope'] != null) {
      if (jsonDecode(widget.message['scope']).containsKey('email')) {
        scope['email'] = await getEmail();
      }

      if (jsonDecode(widget.message['scope']).containsKey('derivedSeed')) {
        scope['derivedSeed'] = await getDerivedSeed(widget.message['appId']);
      }
    }

    await makePermissionPrefs();
  }

  finishLogin() {
    cancelBtnVisible = true;
    setState(() {
      showScopeAndEmoji = true;
      showPinfield = false;
    });
  }

  Widget scopeEmojiView() {
    return Container(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 24.0, left: 24.0),
                  child: Text(
                    isMobileCheck ? scopeTextMobile : scopeText,
                    style: TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: SizedBox(
                  height: 200.0,
                  child: PreferenceDialog(
                    scope: scope,
                    appId: widget.message['appId'],
                    callback: cancelIt,
                    type: 'login',
                  )),
            ),
            Visibility(
              visible: !isMobileCheck,
              child: Expanded(
                flex: 2,
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          ImageButton(imageList[0], selectedImageId,
                              imageSelectedCallback),
                          ImageButton(imageList[1], selectedImageId,
                              imageSelectedCallback),
                          ImageButton(imageList[2], selectedImageId,
                              imageSelectedCallback),
                          ImageButton(imageList[3], selectedImageId,
                              imageSelectedCallback),
                        ])),
              ),
            ),
            Visibility(
              visible: isMobileCheck,
              child: RaisedButton(
                shape: new RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
                color: Theme.of(context).accentColor,
                child: Text(
                  'Accept',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                onPressed: () {
                  sendIt();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: new Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Login'),
          elevation: 0.0,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).primaryColor,
          child: Container(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: Container(
                child: Column(
                  children: <Widget>[
                    Visibility(
                      visible: showPinfield,
                      child: Expanded(
                        flex: 2,
                        child: Center(child: Text(helperText)),
                      ),
                    ),
                    Visibility(
                      visible: showPinfield,
                      child: Expanded(
                        flex: 6,
                        child: showPinfield
                            ? PinField(callback: (p) => pinFilledIn(p))
                            : Container(),
                      ),
                    ),
                    Visibility(
                      visible: showScopeAndEmoji,
                      child: Expanded(flex: 6, child: scopeEmojiView()),
                    ),
                    Visibility(
                      visible: cancelBtnVisible,
                      child: Expanded(
                        flex: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FlatButton(
                            child: Text(
                              "It wasn\'t me - cancel",
                              style: TextStyle(
                                  fontSize: 16.0, color: Color(0xff0f296a)),
                            ),
                            onPressed: () {
                              cancelIt();
                              Navigator.of(context).pop();
                              _onWillPop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  imageSelectedCallback(imageId) {
    setState(() {
      selectedImageId = imageId;
    });

    if (selectedImageId != -1 || isMobile()) {
      if (isMobile() || selectedImageId == correctImage) {
        setState(() {
          print('send it again');
          sendIt();
        });
      } else {
        setState(() {
          print('send it again');
          sendIt();
        });
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(content: Text('Oops... that\'s the wrong emoji')));
      }
    } else {
      _scaffoldKey.currentState
          .showSnackBar(SnackBar(content: Text('Please select an emoji')));
    }
  }

  pinFilledIn(p) async {
    final pin = await getPin();
    if (pin == p) {
      print('Onto showing scopes and emojis');
      return finishLogin();
    } else {
      _scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Oops... you entered the wrong pin')));
    }
  }

  cancelIt() async {
    cancelLogin(await getDoubleName());
    Navigator.popUntil(context, ModalRoute.withName('/'));
    var index = 0;

    for (var flutterWebViewPlugin in flutterWebViewPlugins) {
      if (flutterWebViewPlugin != null) {
        if (index == lastAppUsed) {
          flutterWebViewPlugin.show();
          showButton = true;
        }
        index++;
      }
    }
  }

  sendIt() async {
    print('sendIt');
    var state = widget.message['state'];

    var publicKey = widget.message['appPublicKey']?.replaceAll(" ", "+");
    bool hashMatch = RegExp(r"[^A-Za-z0-9]+").hasMatch(state);
    print("hash match?? " + hashMatch.toString() + " false is ok");
    if (hashMatch) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('States can only be alphanumeric [^A-Za-z0-9]'),
      ));
      return;
    }

    var signedHash = signData(state, await getPrivateKey());
    var tmpScope = Map();

    try {
      tmpScope = await buildScope();
    } catch (exception) {
      print(exception);
    }

    var data = encrypt(jsonEncode(tmpScope), publicKey, await getPrivateKey());

    await sendData(state, await signedHash, await data, selectedImageId);

    if (selectedImageId == correctImage || isMobile()) {
      if (widget.closeWhenLoggedIn && isMobile()) {
        if (Platform.isIOS) {
          Navigator.popUntil(context, ModalRoute.withName('/'));
          Navigator.pushNamed(context, '/success');
        } else {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      } else {
        try {
          Navigator.popUntil(context, ModalRoute.withName('/'));
          Navigator.pushNamed(context, '/success');
        } catch (e) {}
      }
    }
  }

  dynamic buildScope() async {
    Map tmpScope  = new Map.from(scope);

    var json = jsonDecode(await getScopePermissions());
    var permissions = json[widget.message['appId']]; // scope['derivedSeed']['appId']
    var keysOfPermissions = permissions.keys.toList();

    print("====================");
    print(tmpScope);
    print(permissions);
    print(keysOfPermissions); 
    print("--------------------");

    keysOfPermissions.forEach((var value) {
      if (!permissions[value]['enabled']) {
        tmpScope.remove(value);
      }
    });

    return tmpScope;
  }

  bool checkMobile() {
    var mobile = widget.message['mobile'];
    if (mobile == true || mobile == 'true') {
      return true;
    } else {
      return false;
    }
  }

  bool isMobile() {
    var mobile = widget.message['mobile'];

    if (mobile is String) {
      return mobile == 'true';
    } else if (mobile is bool) {
      return mobile == true;
    }

    return false;
  }

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }

    try {
      return double.tryParse(s) != null;
    } catch (e) {
      return false;
    }
  }
}
