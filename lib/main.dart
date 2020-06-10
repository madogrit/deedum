import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:deedum/content.dart';
import 'package:deedum/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';

void main() {
  runApp(BrowserApp());
}

class BrowserApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'deedum',
      theme: ThemeData(
        fontFamily: "Merriweather",
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Browser(),
    );
  }
}

class Browser extends StatefulWidget {
  Browser({Key key}) : super(key: key);

  @override
  _BrowserState createState() => _BrowserState();
}

class UriBar extends StatelessWidget {
  UriBar(
      {this.controller,
      this.loading,
      this.onContent,
      this.onSearch,
      this.onLoad,
      this.onDone});
  final TextEditingController controller;
  final loading;
  final onContent;
  final onSearch;
  final onDone;
  final onLoad;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          flex: 1,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: loading ? Colors.purple : Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Padding(
                  padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: TextField(
                      controller: controller,
                      onSubmitted: (value) {
                        onURI("", value, onContent, onLoad, onDone, []);
                      }))))
    ]);
  }
}

class _BrowserState extends State<Browser> {
  TextEditingController _controller;
  ContentData _content;
  Map<Uri, ContentData> _cache = {};
  List<Uri> _history = [];
  bool _loading = false;

  void initState() {
    super.initState();
    _controller = TextEditingController();
    _handleInit();
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleInit() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recent = (prefs.getStringList('recent') ?? []);
    var content = recent.map((s) {
      return "=> $s";
    }).toList();
    content.insertAll(0, [
      "# Links",
      "=> gemini://gemini.circumlunar.space/ Project Gemini",
      "=> gemini://typed-hole.org/ Typed Hole",
      "=> gemini://gus.guru/ Gemini Universal Search",
      "# Recent"
    ]);

    var contentData = ContentData(content: content, mode: "content");

    setState(() {
      var uri = Uri.parse("gb://recent/");
      _controller.text = uri.toString();
      _history.add(uri);
      _cache[uri] = contentData;
      _content = contentData;
    });
  }

  void _handleLoad() async {
    setState(() {
      _loading = true;
    });
  }

  void _handleDone() async {
    setState(() {
      _loading = false;
    });
  }

  void _handleContent(Uri uri, ContentData contentData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recent = (prefs.getStringList('recent') ?? []);
    recent.remove(uri.toString());
    recent.add(uri.toString());
    if (recent.length > 10) {
      recent = recent.skip(recent.length - 10).toList();
    }

    prefs.setStringList('recent', recent);

    setState(() {
      _controller.text = uri.toString();
      _cache[uri] = contentData;
      if (_history.isEmpty || _history.last != uri) {
        _history.add(uri);
      }
      _content = contentData;
    });
  }

  Future<bool> _handleBack() async {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _content = _cache[_history.last];
      });
      _controller.text = _history.last.toString();
      return false;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _handleBack,
        child: Scaffold(
            backgroundColor:
                (_content != null && _content.mode == "error") ? Colors.deepOrange : Colors.white,
            appBar: AppBar(
                backgroundColor: Colors.orange,
                title: UriBar(
                  controller: _controller,
                  onLoad: _handleLoad,
                  onDone: _handleDone,
                  onContent: _handleContent,
                  loading: _loading,
                )),
            body: SingleChildScrollView(
                key: ObjectKey(_history.isEmpty ? "first" : _history.last),
                child: Content(
                  contentData: _content,
                  onSearch: (String search) {
                    if (search.trim().isNotEmpty) {
                      var uri = Uri.parse(_controller.text);
                      var x = Uri(queryParameters: {search: null});

                      onURI("", uri.toString() + x.toString(), _handleContent,
                          _handleLoad, _handleDone, []);
                    }
                  },
                  onLink: (String link) {
                    onURI(_controller.text, link, _handleContent, _handleLoad,
                        _handleDone, []);
                  },
                ))));
  }
}