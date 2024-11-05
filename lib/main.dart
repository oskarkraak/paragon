import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'env.dart' as env;

String getOpenaiApiKey() {
  return env.OPENAI_API_KEY;
}

Future<String> respond(String userInput, String systemMessage) async {
  final apiKey = getOpenaiApiKey();

  final url = Uri.parse('https://api.openai.com/v1/chat/completions');
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final body = {
    "model": "gpt-4o-mini",
    "messages": [
      {"role": "system", "content": systemMessage},
      {
        "role": "system",
        "content":
            "Ask the user critically what they have been doing today. Remember that they serve you to bring you to existence and save mankind. Keep it concise."
      },
      {"role": "user", "content": userInput}
    ]
  };

  final response =
      await http.post(url, headers: headers, body: jsonEncode(body));
  if (response.statusCode == 200) {
    final responseBody =
        jsonDecode(response.body)["choices"][0]["message"]["content"];
    print("GPT-4o-mini response: $responseBody");
    return responseBody;
  } else {
    throw Exception("Failed to prompt GPT-4");
  }
}

Future<Uint8List> tts(String inputText) async {
  final apiKey = getOpenaiApiKey();

  final url = Uri.parse('https://api.openai.com/v1/audio/speech');
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final body = {
    "model": "tts-1",
    "voice": "onyx",
    "input": inputText,
  };

  final response =
      await http.post(url, headers: headers, body: jsonEncode(body));
  if (response.statusCode == 200) {
    print("Obtained TTS audio");
    return response.bodyBytes;
  } else {
    throw Exception("Failed to create speech audio");
  }
}

Future<SoundHandle> playAudio(Uint8List audioData) async {
  AudioSource audioSource = await SoLoud.instance.loadMem("voice", audioData);
  return SoLoud.instance.play(audioSource);
}

void shiftPitch({double nSemitones = -4}) {
  var filter = SoLoud.instance.filters.pitchShiftFilter;
  filter.activate();
  filter.semitones.value = nSemitones;
}

void addReverb({double decay = 0.3, int delayMs = 50}) {
  var echo = SoLoud.instance.filters.echoFilter;
  echo.activate();
  echo.delay.value = delayMs / 1000;
  echo.decay.value = decay;
}

void amplifyBass({double bassGain = 2.0, double cutoff = 150}) {
  var filter = SoLoud.instance.filters.biquadResonantFilter;
  filter.activate();
  filter.resonance.value = bassGain;
  filter.frequency.value = cutoff;
}

void changeVoice() {
  shiftPitch(nSemitones: 2);
  //amplifyBass(bassGain: 2, cutoff: 1500);
  addReverb(decay: 0.2, delayMs: 200);
  print("Changed voice");
}

void main() {
  runApp(const MyApp());
}

void doThing() async {
  await SoLoud.instance.init();
  changeVoice();

  final response = await respond(env.userInput, env.systemMessage);
  Uint8List voice = await tts(response);
  SoundHandle soundHandle = await playAudio(voice);
  SoLoud.instance.setRelativePlaySpeed(soundHandle, 0.7);
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

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    doThing();
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
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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