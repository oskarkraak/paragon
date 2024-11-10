import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'paragon - alpha v1',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: Colors.deepPurple.shade900,
          onPrimary: Colors.white,
          secondary: Colors.teal.shade900,
          onSecondary: Colors.white,
          error: Colors.red.shade700,
          onError: Colors.white,
          background: Colors.black,
          onBackground: Colors.grey.shade300,
          surface: Colors.grey.shade800,
          onSurface: Colors.grey.shade100,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add({"role": "user", "content": userMessage});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await respond(userMessage, env.systemMessage);
      setState(() {
        _messages.add({"role": "assistant", "content": response});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "Error: $e"});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('paragon'),
            const Text('alpha v1', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUserMessage = message["role"] == "user";
                return Align(
                  alignment: isUserMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUserMessage
                          ? Colors.teal.shade900
                              .withOpacity(0.7) // AI message color
                          : Colors.deepPurpleAccent
                              .withOpacity(0.3), // User message color
                      borderRadius: isUserMessage
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(8.0),
                              topRight: Radius.circular(8.0),
                              bottomLeft: Radius.circular(8.0),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(8.0),
                              topRight: Radius.circular(8.0),
                              bottomRight: Radius.circular(8.0),
                            ),
                    ),
                    child: Text(
                      message["content"] ?? "",
                      style: TextStyle(
                        color: isUserMessage
                            ? Colors.tealAccent
                            : const Color.fromARGB(255, 242, 168, 255),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
