import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:threebotlogin/services/cryptoService.dart';
import 'package:threebotlogin/services/userService.dart';
import 'package:http/http.dart' as http;
import 'package:threebotlogin/widgets/SingleApp.dart';
import 'package:threebotlogin/main.dart';
import 'package:threebotlogin/services/toolsService.dart';
import 'package:threebotlogin/services/openKYCService.dart';
import 'CustomDialog.dart';
import 'package:url_launcher/url_launcher.dart';

class AppSelector extends StatefulWidget {
  final Function(int colorData) notifyParent;
  final _AppSelectorState instance = _AppSelectorState();

  AppSelector({Key key, this.notifyParent}) : super(key: key);

  @override
  _AppSelectorState createState() => instance;
}

class _AppSelectorState extends State<AppSelector> {
  String kAndroidUserAgent =
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36';
  bool isLaunched = false;

  Future<void> launchApp(size, appId) async {
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
        final request = new http.Request('GET', Uri.parse(url))
          ..followRedirects = false;
        final response = await client.send(request);
        logger.log('-----');
        logger.log(response.headers);
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

        print("==================");
        print(scope);
        print("==================");

        if (scope != null && scope.contains("\"email\":")) {
          scopeData['email'] = await getEmail();
          print("adding scope");
        }

        print("==================");
        print(scopeData);
        print("==================");

        var jsonData = jsonEncode(
            (await encrypt(jsonEncode(scopeData), publickey, privateKey)));
        var data = Uri.encodeQueryComponent(jsonData); //Uri.encodeFull();
        loadUrl =
            'https://$appName$redirecturl${union}username=${await getDoubleName()}&signedhash=${Uri.encodeComponent(await signedHash)}&data=$data';

        logger.log("!!!loadUrl: " + loadUrl);
        var cookieList = List<Cookie>();
        cookieList.add(Cookie.fromSetCookieValue(cookies));

        flutterWebViewPlugins[appId]
            .launch(loadUrl,
                rect: Rect.fromLTWH(0.0, 75, size.width, size.height - 75),
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
                rect: Rect.fromLTWH(0.0, 75, size.width, size.height - 75),
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

        // This should be removed in the future!
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

        flutterWebViewPlugins[appId].reloadUrl(loadUrl);
        print("Eval result: $res");

        logger.log("Launching App" + [appId].toString());
      } else {
        flutterWebViewPlugins[appId]
            .launch(loadUrl,
                rect: Rect.fromLTWH(0.0, 75, size.width, size.height - 75),
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
    } on NoSuchMethodError catch (exception) {
      logger.log('error caught: $exception');
      apps[appId]['errorText'] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final prefsF = SharedPreferences.getInstance();

    prefsF.then((pres) {
      if (!isLaunched && pres.containsKey('firstvalidation')) {
        isLaunched = true;
        for (var app in apps) {
          logger.log(app['url']);
          logger.log("launching app " + app['id'].toString());
          if (new List<String>.from(app['permissions']).length == 0 &&
              !(Platform.isIOS && app['openInBrowser'])) {
            launchApp(size, app['id']);
          }
        }
      }
    });

    return Container(
      padding: EdgeInsets.only(left: 0.0),
      height: 0.7 * size.height,
      child: PageView.builder(
        physics: BouncingScrollPhysics(),
        itemCount: apps.length,
        controller: PageController(viewportFraction: 0.8),
        itemBuilder: (BuildContext ctxt, int index) {
          return SingleApp(apps[index], updateApp);
        },
      ),
    );
  }

  void sendVerificationEmail() async {
    final snackbarResending = SnackBar(
        content: Text('Resending verification email...'),
        duration: Duration(seconds: 1));
    Scaffold.of(context).showSnackBar(snackbarResending);
    await resendVerificationEmail();
    _showResendEmailDialog();
  }

  void _showResendEmailDialog() {
    showDialog(
      context: context,
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

  Future<void> updateApp(app) async {
    if (Platform.isIOS && app['openInBrowser']) {
      String appid = app['appid'];
      String redirecturl = app['redirecturl'];
      launch('https://$appid$redirecturl#username=${await getDoubleName()}&derivedSeed=${Uri.encodeQueryComponent(await getDerivedSeed(appid))}', forceSafariVC: false);
    } else {
      if (!app['disabled']) {
        final emailVer = await getEmail();
        if (emailVer['verified']) {
          if (!app['errorText']) {
            final prefs = await SharedPreferences.getInstance();
            final size = MediaQuery.of(context).size;

            if (!prefs.containsKey('firstvalidation')) {
              isLaunched = true;

              for (var oneApp in apps) {
                if (new List<String>.from(oneApp['permissions']).length == 0 &&
                    app['id'] != oneApp['id'] &&
                    !(Platform.isIOS && app['openInBrowser'])) {
                  logger.log(oneApp['url']);
                  logger.log("launching app " + oneApp['id'].toString());
                  launchApp(size, oneApp['id']);
                }
              }
              prefs.setBool('firstvalidation', true);
            }

            widget.notifyParent(app['color']);
            showButton = true;
            lastAppUsed = app['id'];
            keyboardUsedApp = app['id'];
            print("keyboardapp open: " + keyboardUsedApp.toString());
            if (flutterWebViewPlugins[app['id']] == null) {
              await launchApp(size, app['id']);
              logger.log("Webviews was null");
            }
            // The launch can change the webview to null if permissions weren't granted
            if (flutterWebViewPlugins[app['id']] != null &&
                !(Platform.isIOS && app['openInBrowser'])) {
              logger.log("Webviews is showing");
              flutterWebViewPlugins[app['id']].show();
            }
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) => CustomDialog(
                image: Icons.error,
                title: "Service Unavailable",
                description: new Text("Service Unavailable"),
                actions: <Widget>[
                  // usually buttons at the bottom of the dialog
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
            builder: (BuildContext context) => CustomDialog(
              image: Icons.error,
              title: "Please verify email",
              description:
                  new Text("Please verify email before using this app"),
              actions: <Widget>[
                // usually buttons at the bottom of the dialog
                FlatButton(
                  child: new Text("Ok"),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                FlatButton(
                  child: new Text("Resend email"),
                  onPressed: () {
                    sendVerificationEmail();
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
          builder: (BuildContext context) => CustomDialog(
            image: Icons.error,
            title: "Coming soon",
            description: new Text("This will be available soon."),
            actions: <Widget>[
              // usually buttons at the bottom of the dialog
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
  }

  void showPermissionsNeeded(BuildContext context, appId) {
    flutterWebViewPlugins[appId].close();
    flutterWebViewPlugins[appId] = null;
    widget.notifyParent(0xFF0f296a);
    showDialog(
      context: context,
      builder: (BuildContext context) => CustomDialog(
        image: Icons.error,
        title: "Need permissions",
        description: Container(
          child: Text(
            "Some ungranted permissions are needed to run this.",
            textAlign: TextAlign.center,
          ),
        ), //TODO: if iOS -> place link to settings
        actions: <Widget>[
          // usually buttons at the bottom of the dialog
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
