import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _counter = 0;
  WebViewController controller;
  bool isLoading = false;
  bool isError = false;
  String currentUrl = '';
  String initialUrl = 'https://flutter.dev/'; //your website url
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
  }

  Future<void> _initWebView() async {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('Chrome/5.0 (Linux; Android 12) Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              isError = false;
              currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (error) => _handleError(error),
          onNavigationRequest: (request) => _handleNavigation(request),
        ),
      );

    // Add file picker support for Android
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }

    _loadInitialUrl();
  }

  void _loadInitialUrl() async {
    try {
      await controller
          .loadRequest(
        Uri.parse('${widget.initialUrl}'),
      )
          .timeout(const Duration(seconds: 30), onTimeout: () {
        if (isLoading) {
          if (mounted) {
            setState(() {
              isError = true;
              isLoading = false;
            });
          }
        }
      });
      Future.delayed(const Duration(seconds: 60), () {
        if (isLoading) {
          setState(() {
            isError = true;
            isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => isError = true);
      }
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.parse(request.url);
    // Add authorization header to all requests
    if (request.isMainFrame) {
      controller.loadRequest(
        Uri.parse(request.url),
      );
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleError(WebResourceError error) {
    // if (error.errorCode == -6) {
    //   _handleTokenExpiration();
    // } else {
    //   setState(() => isError = true);
    // }
    print('Web resource error: \n ==================================\n');
    print(error);
    if (error.errorType == WebResourceErrorType.authentication) {
      _handleTokenExpiration();
    }
    // Check if the error
    if (((error.url != currentUrl) == true) &&
        ((Uri.parse(error.url.toString()).host != Uri.parse(currentUrl).host) ==
            true)) {
      print(
          'Ignored error Because Url: \n =========================================== \n Error code: ${error.errorCode} \n Error URL: ${error.url} \n Error Description: ${error.description}  \n $currentUrl \n ===========================================');
      return;
    }

    if (mounted) {
      setState(() {
        isError = true;
      });
    }
  }

  //webview file manager
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      // If the input accepts images and has a capture attribute, open the camera.
      if (params.acceptTypes.any((type) => type == 'image/*') &&
          params.mode == FileSelectorMode.open) {
        final picker = ImagePicker();
        final photo = await picker.pickImage(source: ImageSource.camera);
        if (photo == null) return [];
        return [Uri.file(photo.path).toString()];
      }
      // If the input accepts video, allow video recording.
      else if (params.acceptTypes.any((type) => type == 'video/*') &&
          params.mode == FileSelectorMode.open) {
        final picker = ImagePicker();
        final video = await picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 10));
        if (video == null) return [];
        return [Uri.file(video.path).toString()];
      }
      // For general file picking, use the FilePicker package.
      else if (params.mode == FileSelectorMode.openMultiple) {
        final result = await FilePicker.platform.pickFiles(allowMultiple: true);
        if (result == null) return [];
        return result.files
            .where((file) => file.path != null)
            .map((file) => Uri.file(file.path!).toString())
            .toList();
      } else {
        final result = await FilePicker.platform.pickFiles();
        if (result == null) return [];
        return [Uri.file(result.files.single.path!).toString()];
      }
    } catch (e) {
      return [];
    }
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WebViewWidget(controller: controller),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
