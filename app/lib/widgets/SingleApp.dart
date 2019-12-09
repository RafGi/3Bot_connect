import 'package:flutter/material.dart';

class SingleApp extends StatefulWidget {
  final Map app;
  final updateAppCallback;

  SingleApp(this.app, this.updateAppCallback, {Key key}) : super(key: key);

  _SingleAppState createState() => _SingleAppState();
}

class _SingleAppState extends State<SingleApp> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: RawMaterialButton(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/" + widget.app['bg']),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                colorFilter: widget.app['disabled']
                    ? ColorFilter.mode(
                        Colors.black.withAlpha(100), BlendMode.darken)
                    : ColorFilter.mode(
                        Theme.of(context).primaryColor.withAlpha(200),
                        BlendMode.multiply)),
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
            boxShadow: [
              new BoxShadow(
                  color: Colors.black, offset: Offset(1, 1), blurRadius: 2.0)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              widget.app['content'],
              SizedBox(
                height: 10,
              ),
              Text(
                widget.app['subheading'],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        onPressed: () {
          widget.updateAppCallback(widget.app);
        },
      ),
    );
  }
}
