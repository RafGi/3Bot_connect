import 'dart:async';
import 'dart:io';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threebotlogin/screens/LoginScreen.dart';
import 'package:threebotlogin/screens/MobileRegistrationScreen.dart';
import 'package:threebotlogin/services/3botService.dart';
import 'package:threebotlogin/services/toolsService.dart';
import 'package:threebotlogin/services/userService.dart';
import 'package:threebotlogin/services/firebaseService.dart';
import 'package:threebotlogin/services/cryptoService.dart';
import 'package:package_info/package_info.dart';
import 'package:threebotlogin/main.dart';
import 'package:threebotlogin/widgets/CustomDialog.dart';
import 'package:threebotlogin/widgets/BottomNavbar.dart';
import 'package:threebotlogin/widgets/CustomScaffold.dart';
import 'package:threebotlogin/widgets/PreferenceWidget.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ErrorScreen.dart';
import 'RegistrationWithoutScanScreen.dart';
import 'package:threebotlogin/services/openKYCService.dart';
import 'dart:convert';
import 'package:keyboard_visibility/keyboard_visibility.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  final Widget homeScreen;

  HomeScreen({Key key, this.homeScreen}) : super(key: key);

  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool openPendingLoginAttempt = true;
  String doubleName = '';
  var email;
  String initialLink = null;
  int selectedIndex = 0;
  AppBar appBar;
  BottomNavBar bottomNavBar;
  BuildContext bodyContext;
  Size preferredSize;
  bool isLoading = false;
  int failedApp;
  bool chatViewIsShown = false;
  bool isRegistered = false;

  // We will treat this error as a singleton
  WebViewHttpError webViewError;

  final navbarKey = new GlobalKey<BottomNavBarState>();
  bool showSettings = false;
  bool showPreference = false;

  @override
  void initState() {
    getEmail().then((e) {
      setState(() {
        email = e;
      });
    });

    if (initialLink == null) {
      getLinksStream().listen((String incomingLink) {
        logger.log('Got initial link from stream: ' + incomingLink);
        checkWhatPageToOpen(Uri.parse(incomingLink));
      });
    }

    super.initState();
    KeyboardVisibilityNotification().addNewListener(
      onChange: (bool visible) {
        webViewResizer(visible);
      },
    );
    WidgetsBinding.instance.addObserver(this);
    onActivate(true);
  }

  Future<void> webViewResizer(keyboardUp) async {
    double keyboardSize;
    var size = MediaQuery.of(context).size;
    print(MediaQuery.of(context).size.height.toString() + " size of screen");
    var appKeyboard = flutterWebViewPlugins[keyboardUsedApp];
    print(appKeyboard);
    print(appKeyboard.webview);

    Future.delayed(
        Duration(milliseconds: 150),
        () => {
              // Only resize if not on ios..
              if (keyboardUp && !Platform.isIOS)
                {
                  keyboardSize = MediaQuery.of(context).viewInsets.bottom,
                  flutterWebViewPlugins[keyboardUsedApp].resize(
                      Rect.fromLTWH(
                          0,
                          appBar.preferredSize.height,
                          size.width,
                          size.height -
                              keyboardSize -
                              appBar.preferredSize.height),
                      instance: appKeyboard.webview),
                  print(keyboardSize.toString() + " size keyboard at opening"),
                  print('inside true keyboard')
                }
              else
                {
                  keyboardSize = MediaQuery.of(context).viewInsets.bottom,
                  flutterWebViewPlugins[keyboardUsedApp].resize(
                      Rect.fromLTWH(0, appBar.preferredSize.height,
                          preferredSize.width, preferredSize.height),
                      instance: appKeyboard.webview),
                  print(keyboardSize.toString() + " size keyboard at closing"),
                  print('inside false keyboard')
                }
            });
  }

  Future<Null> initUniLinks() async {
    initialLink = await getInitialLink();

    if (initialLink != null) {
      logger.log('Found initialLink: ' + initialLink);
      checkWhatPageToOpen(Uri.parse(initialLink));
    }
  }

  checkWhatPageToOpen(Uri link) async {
    if (link.host == 'register') {
      logger.log('Register via link');
      openPage(RegistrationWithoutScanScreen(
        link.queryParameters,
        resetPin: false,
      ));
    } else if (link.host == "registeraccount") {
      logger.log('registeraccount HERE: ' + link.queryParameters['doubleName']);

      // Check if we already have an account registered before showing this screen.
      String doubleName = await getDoubleName();
      String privateKey = await getPrivateKey();

      if (doubleName == null || privateKey == null) {
        Navigator.popUntil(context, ModalRoute.withName('/'));
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MobileRegistrationScreen(
                    doubleName: link.queryParameters['doubleName'])));
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => CustomDialog(
            image: Icons.check,
            title: "You're already logged in",
            description: new Text(
                "We cannot create a new account, you already have an account registered on your device. Please restart the application if this message persists."),
            actions: <Widget>[
              FlatButton(
                child: new Text("Ok"),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      }
    }
    logger.log('==============');
  }

  openPage(page) {
    Navigator.popUntil(context, ModalRoute.withName('/'));
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void checkIfThereAreLoginAttempts(dn) async {
    if (await getPrivateKey() != null && deviceId != null) {
      checkLoginAttempts(dn).then((attempt) {
        logger.log("Checking if there are login attempts.");
        try {
          if (attempt.body != '' && openPendingLoginAttempt) {
            logger.log("Found a login attempt, opening ...");

            // Navigator.popUntil(context, ModalRoute.withName('/'));

            Navigator.popUntil(context, (route) {
              if (route.settings.name == "/" ||
                  route.settings.name == "/registered" ||
                  route.settings.name == "/preference") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(jsonDecode(attempt.body),
                        closeWhenLoggedIn: true),
                  ),
                );
              }
              return true;
            });
          } else {
            logger.log("We currently have no open login attempts.");
          }
        } catch (exception) {
          logger.log(exception);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onActivate(false);
    }
  }

  Future onActivate(bool initFirebase) async {
    var buildNr = (await PackageInfo.fromPlatform()).buildNumber;
    logger.log('Current buildnumber: ' + buildNr);

    int response = await checkVersionNumber(context, buildNr);

    if (response == 1) {
      if (initFirebase) {
        initFirebaseMessagingListener(context);
      }

      String tmpDoubleName = await getDoubleName();

      // Check if the user didn't click the notification.

      checkIfThereAreLoginAttempts(tmpDoubleName);
      await initUniLinks();

      if (tmpDoubleName != null) {
        var sei = await getSignedEmailIdentifier();
        var email = await getEmail();

        logger.log("sei: " + sei.toString());

        if (sei != null &&
            sei.isNotEmpty &&
            email["email"] != null &&
            email["verified"]) {
          logger.log(
              "Email is verified and we have a signed email to verify this verification to a third party");

          logger.log("Email: ", email["email"]);
          logger.log("Verification status: ", email["verified"].toString());
          logger.log("Signed email: ", sei);

          // We could recheck the signed email here, but this seems to be overkill, since its already verified.
        } else {
          logger.log(
              "We are missing email information or have not been verified yet, attempting to retrieve data ...");

          logger.log("Email: ", email["email"]);
          logger.log("Verification status: ", email["verified"].toString());
          logger.log("Signed email: ", sei.toString());

          logger.log("Getting signed email from openkyc.");
          getSignedEmailIdentifierFromOpenKYC(tmpDoubleName)
              .then((response) async {
            if (response.statusCode == 404) {
              logger.log(
                  "Can't retrieve signedEmailidentifier, we need to resend email verification.");
              logger.log("Response: " + response.body);
              return;
            }

            var body = jsonDecode(response.body);
            var signedEmailIdentifier = body["signed_email_identifier"];

            if (signedEmailIdentifier != null &&
                signedEmailIdentifier.isNotEmpty) {
              logger.log(
                  "Received signedEmailIdentifier: " + signedEmailIdentifier);

              var vsei = json.decode(
                  (await verifySignedEmailIdentifier(signedEmailIdentifier))
                      .body);

              if (vsei != null &&
                  vsei["email"] == email["email"] &&
                  vsei["identifier"].toLowerCase() ==
                      tmpDoubleName.toLowerCase()) {
                logger.log(
                    "Verified signedEmailIdentifier authenticity, saving data.");
                await saveEmail(vsei["email"], true);
                await saveSignedEmailIdentifier(signedEmailIdentifier);
              } else {
                logger.log(
                    "Couldn't verify authenticity, saving unverified email.");
                await saveEmail(email["email"], false);
                await removeSignedEmailIdentifier();
              }
            } else {
              logger.log(
                  "No valid signed email has been found, please redo the verification process.");
            }
          });
        }

        if (mounted) {
          setState(() {
            doubleName = tmpDoubleName;
          });
        }
      }
    } else if (response == 0) {
      Navigator.pushReplacementNamed(context, '/error');
    } else if (response == -1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ErrorScreen(errorMessage: "Can't connect to server."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    appBar = AppBar(
      backgroundColor: HexColor("#2d4052"),
      elevation: 0.0,
    );

    bottomNavBar = BottomNavBar(
      key: navbarKey,
      selectedIndex: selectedIndex,
      onItemTapped: onItemTapped,
    );

    return CustomScaffold(
      renderBackground: selectedIndex != 0,
      appBar: PreferredSize(
        child: appBar,
        preferredSize: Size.fromHeight(0),
      ),
      body: FutureBuilder(
        future: getDoubleName(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return registered(context);
          } else {
            return notRegistered(context);
          }
        },
      ),
      footer: FutureBuilder(
        future: getDoubleName(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return bottomNavBar;
          } else {
            return new Container(width: 0.0, height: 0.0);
          }
        },
      ),
    );
  }

  void onItemTapped(int index) {
    if (isLoading) {
      flutterWebViewPlugins[selectedIndex].close();
      flutterWebViewPlugins[selectedIndex] = null;
      setState(() {
        isLoading = false;
      });
    }

    setState(() {
      for (var flutterWebViewPlugin in flutterWebViewPlugins) {
        if (flutterWebViewPlugin != null) {
          flutterWebViewPlugin.hide();
        }
      }
      showPreference = false;
      if (!(apps[index]['openInBrowser'] && Platform.isIOS)) {
        selectedIndex = index;
      }
    });
    updateApp(apps[index]);
  }

  void updatePreference(bool preference) {
    setState(() {
      this.showPreference = preference;
    });
  }

  Widget registered(BuildContext context) {
    bodyContext = context;

    if (showPreference) {
      return PreferenceWidget(updatePreference);
    }

    switch (selectedIndex) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SizedBox(height: 50.0),
                !showPreference
                    ? FloatingActionButton(
                        heroTag: "preference",
                        elevation: 0.0,
                        backgroundColor: Colors.transparent,
                        foregroundColor: Theme.of(context).accentColor,
                        child: Icon(Icons.settings),
                        onPressed: () {
                          setState(() {
                            showPreference = true;
                          });
                        })
                    : null
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 200.0,
                  height: 200.0,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    image: DecorationImage(
                        fit: BoxFit.fill, image: AssetImage('assets/logo.png')),
                  ),
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/newLogo.png',
                      height: 40,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        "Bot",
                        style: TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: new EdgeInsets.all(10.0),
                    child: Text("Pages",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        FloatingActionButton(
                          heroTag: "tft",
                          backgroundColor: Colors.redAccent,
                          elevation: 0,
                          onPressed: () => openFfp(0),
                          child: CircleAvatar(
                            backgroundImage: ExactAssetImage(
                                'assets/circle_images/tftokens.jpg'),
                            minRadius: 90,
                            maxRadius: 150,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("TF Tokens"),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        FloatingActionButton(
                          heroTag: "tfgrid",
                          backgroundColor: Colors.greenAccent,
                          elevation: 0,
                          onPressed: () => openFfp(1),
                          child: CircleAvatar(
                            backgroundImage: ExactAssetImage(
                                'assets/circle_images/tfgrid.jpg'),
                            minRadius: 90,
                            maxRadius: 150,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("TF Grid"),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        FloatingActionButton(
                          heroTag: "tftfarmers",
                          backgroundColor: Colors.blueAccent,
                          elevation: 0,
                          onPressed: () => openFfp(2),
                          child: CircleAvatar(
                            backgroundImage: ExactAssetImage(
                                'assets/circle_images/tffarmers.jpg'),
                            minRadius: 90,
                            maxRadius: 150,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("TF Farmers"),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        FloatingActionButton(
                          heroTag: "ffnation",
                          backgroundColor: Colors.grey,
                          elevation: 0,
                          onPressed: () => openFfp(3),
                          child: CircleAvatar(
                            backgroundImage: ExactAssetImage(
                                'assets/circle_images/ffnation.jpg'),
                            minRadius: 90,
                            maxRadius: 150,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("FF Nation"),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        FloatingActionButton(
                          heroTag: "3bot",
                          backgroundColor: Colors.orangeAccent,
                          elevation: 0,
                          onPressed: () => openFfp(4),
                          child: CircleAvatar(
                            backgroundImage: ExactAssetImage(
                                'assets/circle_images/3bot.jpg'),
                            minRadius: 90,
                            maxRadius: 150,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("3Bot"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Column(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(5),
                      child: Text(
                        "More functionality will be added soon.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      case 2:
        return Scaffold(
          backgroundColor: HexColor("#2d4052"),
        );
      default:
        return isLoading
            ? Center(child: CircularProgressIndicator())
            : Container();
    }
  }

  void routeToHome() {
    setState(() {
      selectedIndex = 0;
      showPreference = false;
    });
  }

  void openFfp(int urlIndex) async {
    var ffpInstance = flutterWebViewPlugins[3];
    bool hadToStartInstance = false;
    bool callbackSuccess = false;

    setState(() {
      for (var flutterWebViewPlugin in flutterWebViewPlugins) {
        if (flutterWebViewPlugin != null &&
            ffpInstance != flutterWebViewPlugin) {
          flutterWebViewPlugin.dispose();
        }
      }
      selectedIndex = 3;
    });

    if (ffpInstance == null) {
      await updateApp(apps[3]);
      ffpInstance = flutterWebViewPlugins[3];
      hadToStartInstance = true;
    }

    if (ffpInstance != null) {
      if (hadToStartInstance) {
        ffpInstance.onStateChanged.listen((viewData) async {
          if (viewData.type == WebViewState.finishLoad && !callbackSuccess) {
            await ffpInstance.evalJavascript("window.location.href = \"" +
                apps[3]['ffpUrls'][urlIndex] +
                "\"");
            callbackSuccess = true;
          }
        });
      } else {
        var url = apps[3]['ffpUrls'][urlIndex];

        await ffpInstance.reloadUrl(url);
        return ffpInstance.show();
      }
    }
  }

  ConstrainedBox notRegistered(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
          maxHeight: double.infinity,
          maxWidth: double.infinity,
          minHeight: 250,
          minWidth: 250),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 200.0,
                height: 200.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      fit: BoxFit.fill, image: AssetImage('assets/logo.png')),
                ),
              ),
              SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/newLogo.png',
                    height: 40,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      "Bot",
                      style:
                          TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Welcome to 3Bot connect.',
                    style: TextStyle(fontSize: 24)),
                SizedBox(height: 10),
                RaisedButton(
                  shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(30),
                  ),
                  color: Theme.of(context).primaryColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      new Icon(
                        CommunityMaterialIcons.account_edit,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10.0),
                      Text(
                        'Register Now!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/registration');
                  },
                ),
                RaisedButton(
                  shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(30),
                  ),
                  color: Theme.of(context).accentColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      new Icon(
                        CommunityMaterialIcons.backup_restore,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10.0),
                      Text(
                        'Recover account',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/recover');
                  },
                ),
              ],
            ),
          ),
          Container(),
        ],
      ),
    );
  }

  Size getBottomNavbarHeight() {
    final State state = navbarKey.currentState;
    final RenderBox box = state.context.findRenderObject();

    return box.size;
  }

  Size getPreferredSizeForWebview() {
    var contextSize = MediaQuery.of(bodyContext).size;

    var preferredHeight = contextSize.height -
        appBar.preferredSize.height -
        getBottomNavbarHeight().height;
    var preferredWidth = contextSize.width;

    return new Size(preferredWidth, preferredHeight);
  }

  Future<void> updateApp(app) async {
    if (Platform.isIOS && app['openInBrowser']) {
      String appid = app['appid'];
      String redirecturl = app['redirecturl'];
      launch(
          'https://$appid$redirecturl#username=${await getDoubleName()}&derivedSeed=${Uri.encodeQueryComponent(await getDerivedSeed(appid))}',
          forceSafariVC: false);
    } else if (!app['disabled']) {
      final emailVer = await getEmail();
      if (emailVer['verified'] || selectedIndex == 1) {
        if (!app['errorText']) {
          final prefs = await SharedPreferences.getInstance();

          preferredSize = getPreferredSizeForWebview();

          if (!prefs.containsKey('firstvalidation')) {
            logger.log(app['url']);
            logger.log("launching app " + app['id'].toString());

            await launchApp(preferredSize, app['id']);
            await prefs.setBool('firstvalidation', true);
          }

          showButton = true;
          lastAppUsed = app['id'];
          keyboardUsedApp = app['id'];
          print("keyboardapp open: " + keyboardUsedApp.toString());
          if (failedApp == app['id']) {
            await launchApp(preferredSize, app['id']);
            return;
          }
          if (flutterWebViewPlugins[app['id']] == null) {
            await launchApp(preferredSize, app['id']);
            logger.log("Webviews was null");
          }
          if (flutterWebViewPlugins[app['id']] != null) {
            logger.log("Webviews is showing");
            if (!isLoading) {
              await flutterWebViewPlugins[app['id']].show();
            }
          }
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => CustomDialog(
              image: Icons.error,
              title: "Service Unavailable",
              description: new Text("Service Unavailable"),
              actions: <Widget>[
                FlatButton(
                  child: new Text("Ok"),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        }
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => CustomDialog(
            image: Icons.error,
            title: "Please verify email",
            description: new Text("Please verify email before using this app"),
            actions: <Widget>[
              FlatButton(
                child: new Text("Ok"),
                onPressed: () {
                  Navigator.pop(context);
                  this.routeToHome();
                },
              ),
              FlatButton(
                child: new Text("Resend email"),
                onPressed: () {
                  this.routeToHome();
                  sendVerificationEmail();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> launchApp(size, appId) async {
    this.setState(() => {isLoading = true});
    if (flutterWebViewPlugins[appId] == null) {
      flutterWebViewPlugins[appId] = new FlutterWebviewPlugin();
    }
    try {
      var url = apps[appId]['cookieUrl'];
      var loadUrl = apps[appId]['url'];

      var localStorageKeys = apps[appId]['localStorageKeys'];

      var cookies = '';
      final union = '?';
      if (url != '') {
        final client = http.Client();
        var request = new http.Request('GET', Uri.parse(url))
          ..followRedirects = false;
        var response = await client.send(request);

        if (response.statusCode == 401) {
          url = apps[appId]['cookieUrl'];
          request = new http.Request('GET', Uri.parse(url))
            ..followRedirects = false;
          response = await client.send(request);
        }

        final state =
            Uri.decodeFull(response.headers['location'].split("&state=")[1]);
        final privateKey = await getPrivateKey();
        final signedHash = signData(state, privateKey);

        final redirecturl = Uri.decodeFull(response.headers['location']
            .split("&redirecturl=")[1]
            .split("&")[0]);
        final appName = Uri.decodeFull(
            response.headers['location'].split("appid=")[1].split("&")[0]);
        logger.log(appName);
        final scope = Uri.decodeFull(
            response.headers['location'].split("&scope=")[1].split("&")[0]);
        final publickey = Uri.decodeFull(
            response.headers['location'].split("&publickey=")[1].split("&")[0]);
        logger.log(response.headers['set-cookie'].toString() + " Lower");
        cookies = response.headers['set-cookie'];

        final scopeData = {};

        if (scope != null && scope.contains("\"email\":")) {
          scopeData['email'] = await getEmail();
          print("adding scope");
        }

        var jsonData = jsonEncode(
            (await encrypt(jsonEncode(scopeData), publickey, privateKey)));
        var data = Uri.encodeQueryComponent(jsonData); //Uri.encodeFull();
        loadUrl =
            'https://$appName$redirecturl${union}username=${await getDoubleName()}&signedhash=${Uri.encodeComponent(await signedHash)}&data=$data';

        logger.log("!!!loadUrl: " + loadUrl);
        var cookieList = List<Cookie>();
        cookieList.add(Cookie.fromSetCookieValue(cookies));

        await flutterWebViewPlugins[appId]
            .launch(loadUrl,
                rect: Rect.fromLTWH(
                    0.0, appBar.preferredSize.height, size.width, size.height),
                userAgent: kAndroidUserAgent,
                hidden: true,
                cookies: cookieList,
                withLocalStorage: true,
                permissions: new List<String>.from(apps[appId]['permissions']))
            .then((permissionGranted) {
          if (!permissionGranted) {
            showPermissionsNeeded(context, appId);
          }
        });
      } else if (localStorageKeys != null) {
        await flutterWebViewPlugins[appId]
            .launch(loadUrl + '/error',
                rect: Rect.fromLTWH(
                    0.0, appBar.preferredSize.height, size.width, size.height),
                userAgent: kAndroidUserAgent,
                hidden: true,
                cookies: [],
                withLocalStorage: true,
                permissions: new List<String>.from(apps[appId]['permissions']))
            .then((permissionGranted) {
          if (!permissionGranted) {
            showPermissionsNeeded(context, appId);
          }
        });

        var keys = await generateKeyPair();

        final state = randomString(15);

        final privateKey = await getPrivateKey();
        final signedHash = await signData(state, privateKey);

        var jsToExecute =
            "(function() { try {window.localStorage.setItem('tempKeys', \'{\"privateKey\": \"${keys["privateKey"]}\", \"publicKey\": \"${keys["publicKey"]}\"}\');  window.localStorage.setItem('state', '$state'); } catch (err) { return err; } })();";

        sleep(const Duration(seconds: 1));

        final res =
            await flutterWebViewPlugins[appId].evalJavascript(jsToExecute);
        final appid = apps[appId]['appid'];
        final redirecturl = apps[appId]['redirecturl'];
        var scope = {};
        scope['doubleName'] = await getDoubleName();
        scope['derivedSeed'] = await getDerivedSeed(appid);

        var encrypted =
            await encrypt(jsonEncode(scope), keys["publicKey"], privateKey);
        var jsonData = jsonEncode(encrypted);
        var data = Uri.encodeQueryComponent(jsonData); //Uri.encodeFull();

        loadUrl =
            'https://$appid$redirecturl${union}username=${await getDoubleName()}&signedhash=${Uri.encodeQueryComponent(signedHash)}&data=$data';

        logger.log("!!!loadUrl: " + loadUrl);

        await flutterWebViewPlugins[appId].reloadUrl(loadUrl);
        print("Eval result: $res");

        logger.log("Launching App" + [appId].toString());
      } else {
        await flutterWebViewPlugins[appId]
            .launch(loadUrl,
                rect: Rect.fromLTWH(
                    0.0, appBar.preferredSize.height, size.width, size.height),
                userAgent: kAndroidUserAgent,
                hidden: true,
                cookies: [],
                withLocalStorage: true,
                permissions: new List<String>.from(apps[appId]['permissions']))
            .then((permissionGranted) {
          if (!permissionGranted) {
            showPermissionsNeeded(context, appId);
          }
        });
        logger.log("Launching App" + [appId].toString());
      }

      logger.log(loadUrl);
      logger.log(cookies);

      flutterWebViewPlugins[appId].onStateChanged.listen((viewData) async {
        if (viewData.type == WebViewState.finishLoad && isLoading) {
          this.setState(() => {isLoading = false});
          await flutterWebViewPlugins[appId].show();
        }
      });

      flutterWebViewPlugins[appId].onDestroy.listen((_) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });

      // flutterWebViewPlugins[appId].onHttpError.listen((error) {
      //   if (error.code != "200" && error != webViewError) {
      //     webViewError = error;
      //     showDialog(
      //       context: context,
      //       barrierDismissible: false,
      //       builder: (BuildContext context) => CustomDialog(
      //         image: Icons.error,
      //         title: "Service Unavailable",
      //         description: new Text("Service Unavailable"),
      //         actions: <Widget>[
      //           // usually buttons at the bottom of the dialog
      //           FlatButton(
      //             child: new Text("Ok"),
      //             onPressed: () {
      //               Navigator.pop(context);
      //               setState(() {
      //                 failedApp = appId;
      //                 webViewError = null;
      //               });
      //               this.routeToHome();
      //             },
      //           ),
      //         ],
      //       ),
      //     );
      //   }
      // });
    } on NoSuchMethodError catch (exception) {
      logger.log('error caught: $exception');
      apps[appId]['errorText'] = true;
      setState(() {
        isLoading = false;
      });
    }
  }

  void showPermissionsNeeded(BuildContext context, appId) async {
    await flutterWebViewPlugins[appId].close();
    flutterWebViewPlugins[appId] = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => CustomDialog(
        image: Icons.error,
        title: "Need permissions",
        description: Container(
          child: Text(
            "Some ungranted permissions are needed to run this.",
            textAlign: TextAlign.center,
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: new Text("Ok"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void sendVerificationEmail() async {
    final snackbarResending = SnackBar(
        content: Text('Resending verification email...'),
        duration: Duration(seconds: 1));
    Scaffold.of(bodyContext).showSnackBar(snackbarResending);
    await resendVerificationEmail();
    _showResendEmailDialog();
  }

  void _showResendEmailDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => CustomDialog(
        image: Icons.check,
        title: "Email has been resent.",
        description: new Text("A new verification email has been sent."),
        actions: <Widget>[
          FlatButton(
            child: new Text("Ok"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
