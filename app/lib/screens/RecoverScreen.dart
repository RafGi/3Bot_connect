import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:threebotlogin/helpers/Globals.dart';
import 'package:threebotlogin/services/3botService.dart';
import 'package:threebotlogin/services/cryptoService.dart';
import 'package:threebotlogin/services/openKYCService.dart';
import 'package:threebotlogin/services/userService.dart';

class RecoverScreen extends StatefulWidget {
  final Widget recoverScreen;
  RecoverScreen({Key key, this.recoverScreen}) : super(key: key);
  _RecoverScreenState createState() => _RecoverScreenState();
}

class _RecoverScreenState extends State<RecoverScreen> {
  final doubleNameController = TextEditingController();
  final emailController = TextEditingController();
  final seedPhrasecontroller = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _autoValidate = false;
  bool emailVerified = false;
  bool emailCheck = false;

  String doubleName = '';
  String emailFromForm = '';
  String seedPhrase = '';

  String error = '';

  String privateKey;

  String generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  checkSeedPhrase(doubleName, seedPhrase) async {
    checkSeedLength(seedPhrase);
    var keys = await generateKeysFromSeedPhrase(seedPhrase);

    setState(() {
      privateKey = keys['privateKey'];
    });

    var userInfoResult = await getUserInfo(doubleName);

    if (userInfoResult.statusCode != 200) {
      throw new Exception('User not found');
    }

    var body = json.decode(userInfoResult.body);

    if (body['publicKey'] != keys['publicKey']) {
      throw new Exception('Seed phrase does not correspond to given name');
    }
  }

  continueRecoverAccount() async {
    Map<String, String> keys = await generateKeysFromSeedPhrase(seedPhrase);

    await savePrivateKey(keys['privateKey']);
    await savePublicKey(keys['publicKey']);
    await saveFingerprint(false);
    await saveEmail(emailFromForm, null);
    await saveDoubleName(doubleName);
    await savePhrase(seedPhrase);
    await sendVerificationEmail();
  }

  checkSeedLength(seedPhrase) {
    int seedLength = seedPhrase.split(" ").length;
    if (seedLength <= 23) {
      throw new Exception('Seed phrase is too short');
    } else if (seedLength > 24) {
      throw new Exception('Seed phrase is too long');
    }
  }

  String validateEmail(String value) {
    Pattern pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}';
    RegExp regex = new RegExp(pattern);
    if (!regex.hasMatch(value)) {
      emailCheck = false;
      return 'Enter valid e-mail';
    }
    emailCheck = true;
    return null;
  }

  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    doubleNameController.dispose();
    emailController.dispose();
    seedPhrasecontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Globals.color,
        title: Text('Recover Account'),
      ),
      body: Container(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: recoverForm(),
        ),
      ),
    );
  }

  Widget recoverForm() {
    return new Form(
      key: _formKey,
      autovalidate: _autoValidate,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Please insert your info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.5),
              child: TextFormField(
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Name',
                    suffixText: '.3bot',
                    suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  controller: doubleNameController,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'Please enter your Name';
                    }
                    return null;
                  }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.5),
              child: TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Email'),
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Please enter your Email';
                  }
                  return null;
                },
                controller: emailController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.5),
              child: TextFormField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Seed phrase'),
                controller: seedPhrasecontroller,
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Please enter your Seed phrase';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              error,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              shape: new RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(10),
              ),
              padding: EdgeInsets.all(10),
              child: Text(
                'Recover Account',
                style: TextStyle(color: Colors.white),
              ),
              color: Theme.of(context).primaryColor,
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 10,
                        ),
                        new CircularProgressIndicator(),
                        SizedBox(
                          height: 10,
                        ),
                        new Text("Loading"),
                        SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                );
                setState(() {
                  error = '';
                });
                FocusScope.of(context).requestFocus(new FocusNode());
                setState(() {
                  _autoValidate = true;
                  doubleName = doubleNameController.text + '.3bot';
                  emailFromForm = emailController.text;
                  seedPhrase = seedPhrasecontroller.text;
                  validateEmail(emailFromForm);
                });
                try {
                  if (emailFromForm != null &&
                      emailFromForm.isNotEmpty &&
                      emailCheck == true) {
                    await checkSeedPhrase(doubleName, seedPhrase);
                    await continueRecoverAccount();
                  } else {
                    throw new Exception("");
                  }

                  Navigator.pop(context);
                  Navigator.pop(context, true);
                } catch (e) {
                  Navigator.pop(context, false);
                  setState(() {
                    // error = e.message;
                    error =
                        'Please make sure everything is correctly filled in';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
