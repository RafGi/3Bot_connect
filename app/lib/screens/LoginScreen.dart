import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:threebotlogin/Events/Events.dart';
import 'package:threebotlogin/Events/NewLoginEvent.dart';
import 'package:threebotlogin/Events/PopAllLoginEvent.dart';
import 'package:threebotlogin/services/fingerprintService.dart';
import 'package:threebotlogin/services/toolsService.dart';
import 'package:threebotlogin/widgets/ImageButton.dart';
import 'package:threebotlogin/widgets/PinField.dart';
import 'package:threebotlogin/services/userService.dart';
import 'package:threebotlogin/services/cryptoService.dart';
import 'package:threebotlogin/services/3botService.dart';
import 'package:threebotlogin/widgets/PreferenceDialog.dart';

_LoginScreenState lastState;

class LoginScreen extends StatefulWidget {
  final Widget loginScreen;
  final Widget scopeList;
  final message;
  final bool closeWhenLoggedIn;
  final bool autoLogin;

  LoginScreen(this.message,
      {Key key,
      this.loginScreen,
      this.closeWhenLoggedIn = false,
      this.scopeList,
      this.autoLogin = false})
      : super(key: key);

  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String helperText = '';
  String scopeTextMobile =
      'Please select the data you want to share and press Accept';
  String scopeText =
      'Please select the data you want to share and press the corresponding emoji';

  List<int> imageList = new List();
  Map scope = Map();

  int selectedImageId = -1;
  int correctImage = -1;

  bool cancelBtnVisible = false;
  bool showPinfield = false;
  bool showScopeAndEmoji = false;
  bool isMobileCheck = false;
  String emitCode = randomString(10);
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  close(PopAllLoginEvent e) {
    if (e.emitCode == emitCode) {
      return;
    }
    if (mounted) {
      Navigator.pop(context, false);
    }
  }

  @override
  void initState() {
    super.initState();
    Events().onEvent(PopAllLoginEvent("").runtimeType, close);
    isMobileCheck = checkMobile();

    makePermissionPrefs();

    // Generate EmojiList
    generateEmojiImageList();

    if (widget.autoLogin) {
      sendIt(true);
      return;
    }

    if (Platform.isIOS) {
      goToPinfield();
      checkFingerPrintActive();
    } else {
      checkFingerPrintActive();
    }
    // Events().onEvent(NewLoginEvent().runtimeType, _newLogin);
  }

  void generateEmojiImageList() {
    // Parse correct emoji image id that comes from our API.
    correctImage = parseImageId(widget.message['randomImageId']);

    // Add it to the list
    imageList.add(correctImage);

    // Generate 3 other random emoji image ids
    int generated = 1;
    var rng = new Random();
    while (generated <= 3) {
      var x = rng.nextInt(266) + 1;
      if (!imageList.contains(x)) {
        imageList.add(x);
        generated++;
      }
    }

    // Shuffle the list
    setState(() {
      imageList.shuffle();
    });
  }

  checkFingerPrintActive() async {
    bool isValue = await getFingerprint();

    if (isValue) {
      bool isAuthenticated = await authenticate();

      if (isAuthenticated) {
        // Show scopes + emmoji
        return finishLogin();
      }
    }
    // Show Pinfield
    goToPinfield();
  }

  void goToPinfield() {
    setState(() {
      helperText = 'Enter your pincode to log in';
      showPinfield = true;
      cancelBtnVisible = true;
    });
  }

  bool isRequired(value, givenScope) {
    var decodedValue = jsonDecode(givenScope)[value];
    if (decodedValue == null) return false;
    if (decodedValue is String) {
      return true;
    } else
      return decodedValue && decodedValue != null;
  }

  makePermissionPrefs() async {
    if (widget.message['scope'] != null) {
      if (jsonDecode(widget.message['scope']).containsKey('email')) {
        scope['email'] = await getEmail();
      }

      if (jsonDecode(widget.message['scope']).containsKey('derivedSeed')) {
        scope['derivedSeed'] = await getDerivedSeed(widget.message['appId']);
      }

      if (jsonDecode(widget.message['scope']).containsKey('trustedDevice')) {
        var trustedDevice = {};
        trustedDevice['trustedDevice'] =
            json.decode(widget.message['scope'])['trustedDevice'];
        scope['trustedDevice'] = trustedDevice;
      }
    }

    String scopePermissions = await getScopePermissions();
    if (scopePermissions == null) {
      saveScopePermissions(jsonEncode(scope));
      scopePermissions = jsonEncode(scope);
    }

    var initialPermissions = jsonDecode(scopePermissions);

    if (!initialPermissions.containsKey(widget.message['appId'])) {
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
      saveScopePermissions(jsonEncode(initialPermissions));
    } else {
      List<String> permissions = [
        'doubleName',
        'email',
        'derivedSeed',
        'trustedDevice'
      ];

      permissions.forEach((var permission) {
        if (!initialPermissions[widget.message['appId']]
            .containsKey(permission)) {
          initialPermissions[widget.message['appId']][permission] = {
            'enabled': true,
            'required': isRequired(permission, widget.message['scope'])
          };
        }
      });
      saveScopePermissions(jsonEncode(initialPermissions));
    }
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: RaisedButton(
                  shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(30),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
                  color: Theme.of(context).accentColor,
                  child: Text(
                    'Accept',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  onPressed: () {
                    sendIt(true);
                  },
                ),
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
      child: new Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Login'),
          elevation: 0.0,
        ),
        body: Column(
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
                      style:
                          TextStyle(fontSize: 16.0, color: Color(0xff0f296a)),
                    ),
                    onPressed: () {
                      cancelIt();
                      Navigator.pop(context, false);
                      Events().emit(PopAllLoginEvent(emitCode));
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      onWillPop: () {
        cancelIt();
        return Future.value(true);
      },
    );
  }

  imageSelectedCallback(imageId) {
    setState(() {
      selectedImageId = imageId;
    });

    if (selectedImageId != -1) {
      if (selectedImageId == correctImage) {
        setState(() {
          print('send it again');
          sendIt(true);
        });
      } else {
        setState(() {
          print('send it again');
          sendIt(false);
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
      return finishLogin();
    } else {
      _scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Oops... you entered the wrong pin')));
    }
  }

  cancelIt() async {
    cancelLogin(await getDoubleName());
  }

  sendIt(bool includeData) async {
    var state = widget.message['state'];

    var publicKey = widget.message['appPublicKey']?.replaceAll(" ", "+");
    bool hashMatch = RegExp(r"[^A-Za-z0-9]+").hasMatch(state);

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

    var data =
        await encrypt(jsonEncode(tmpScope), publicKey, await getPrivateKey());
    //push to backend with signed
    if (!includeData) {
      await sendData(
          state, "", null, selectedImageId); // temp fix send empty data
    } else {
      await sendData(state, await signedHash, data, selectedImageId);
    }

    if (scope['trustedDevice'] != null) {
      // Save the trusted deviceid
      saveTrustedDevice(
          widget.message['appId'], scope['trustedDevice']['trustedDevice']);
    }

    if (selectedImageId == correctImage || isMobileCheck) {
      Navigator.pop(context, true);
      Events().emit(PopAllLoginEvent(emitCode));
    }
  }

  dynamic buildScope() async {
    Map tmpScope = new Map.from(scope);

    var json = jsonDecode(await getScopePermissions());
    var permissions = json[widget.message['appId']];
    var keysOfPermissions = permissions.keys.toList();

    keysOfPermissions.forEach((var value) {
      if (!permissions[value]['enabled']) {
        tmpScope.remove(value);
      }
    });

    return tmpScope;
  }

  bool checkMobile() {
    var mobile = widget.message['mobile'];
    return mobile == true || mobile == 'true';
  }

  int parseImageId(String imageId) {
    if (imageId == null || imageId == '') {
      return 1;
    }
    return int.parse(imageId);
  }
}
