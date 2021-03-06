import 'package:flutter/material.dart';
import 'package:threebotlogin/helpers/HexColor.dart';
import 'package:threebotlogin/router.dart';

class Globals {
  static final isInDebugMode = true;
  static final color = HexColor("#2d4052");
  ValueNotifier<bool> emailVerified = ValueNotifier(false);
  final Router router = new Router();

  /* Singleton */
  static final Globals _singleton = new Globals._internal();
  factory Globals() {
    return _singleton;
  }
  Globals._internal() {
    //initialize
  }
}