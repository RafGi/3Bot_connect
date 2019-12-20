import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'main.dart';

void main() {
  var config = Config(
      name: '3Bot Connect',
      threeBotApiUrl: 'https://login.threefold.me/api',
      openKycApiUrl: 'https://openkyc.live/',
      threeBotFrontEndUrl: 'https://login.threefold.me/',
      child: new MyApp());

  init();

  apps = [
    null,
    {
      "content": Text(
        '3bot Wallet',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      "subheading": '',
      "url": 'https://wallet.threefold.me',
      "appid": 'wallet.threefold.me',
      "redirecturl": '/login',
      "bg": 'nbh.png',
      "disabled": false,
      "initialUrl": 'https://wallet.threefold.me',
      "visible": false,
      "id": 1,
      'cookieUrl': '',
      'localStorageKeys': true,
      'color': 0xFF34495e,
      'errorText': false,
      'openInBrowser': true,
      'permissions': ['CAMERA']
    },
    {
      "content": Text(
        'FreeFlowPages',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      "subheading": 'Where privacy and social media co-exist.',
      "url": 'https://freeflowpages.com?crisp=false',
      "bg": 'ffp.jpg',
      "disabled": false,
      "initialUrl": 'https://freeflowpages.com?crisp=false',
      "visible": false,
      "id": 3,
      'cookieUrl':
          'https://freeflowpages.com/user/auth/external?authclient=3bot',
      'color': 0xFF708fa0,
      'errorText': false,
      'openInBrowser': false,
      'permissions': [],
      'ffpUrls': [
        'https://freeflowpages.com/join/tf-tokens?crisp=false',
        'https://freeflowpages.com/join/tf-grid-users?crisp=false',
        'https://freeflowpages.com/join/tf-grid-farming?crisp=false',
        'https://freeflowpages.com/join/freeflownation?crisp=false',
        'https://freeflowpages.com/join/3bot?crisp=false'
      ]
    },
    {
      "content": Text(
        'ChatApp',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      "subheading": 'Chat with your 3Bot',
      "disabled": false,
      'cookieUrl': '',
      "url": 'https://go.crisp.chat/chat/embed/?website_id=1a5a5241-91cb-4a41-8323-5ba5ec574da0',
      "initialUrl": 'https://go.crisp.chat/chat/embed/?website_id=1a5a5241-91cb-4a41-8323-5ba5ec574da0',
      "visible": false,
      "id": 3,
      'color': 0xFF708fa0,
      'errorText': false,
      'openInBrowser': false,
      'permissions': [],
    },
    null,
    {
      "content": Text(
        'Wizard',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      "subheading": 'Chat with your 3Bot',
      "disabled": false,
      'cookieUrl': '',
      "url": 'https://jimber.org/wizard',
      "initialUrl": 'https://jimber.org/wizard',
      "visible": false,
      'color': 0xFF708fa0,
      'errorText': false,
      'openInBrowser': false,
      "id": 4,
      'permissions': []
    },
  ];

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(config);
    logger.log("running main_prod.dart");
  });
}
