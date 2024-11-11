// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'env.dart' as env;

var messages = [
  {"role": "system", "content": env.systemMessage}
];
late String memory;
// ignore: prefer_typing_uninitialized_variables
late final prefs;
bool _isLoading = false;
String? _firstText;
Uint8List? _firstTts;

String getOpenaiApiKey() {
  return env.OPENAI_API_KEY;
}

void stop(BuildContext context) async {
  String newMemory = await updateMemory();
  await prefs.setString('memory', newMemory);
  print("Memory updated to: $newMemory");

  // Show a dialog asking the user if they want to modify the memory string
  showDialog(
    context: context, // You need to pass the context from where you call stop
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Modify Memory'),
        content: const Text('Do you want to modify the memory?'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(), // Dismiss dialog
              child: const Text('No', style: TextStyle(color: Colors.white))),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog
              // Show input dialog for editing the memory
              String? editedMemory =
                  await _editMemoryDialog(context, newMemory);
              if (editedMemory != null) {
                newMemory = editedMemory;
              }
              await prefs.setString('memory', newMemory);
              print("Memory updated to: $newMemory");
            },
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

// Function to show an input dialog for editing memory
Future<String?> _editMemoryDialog(
    BuildContext context, String currentMemory) async {
  final TextEditingController controller =
      TextEditingController(text: currentMemory);

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Edit Memory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new memory text...',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Dismiss dialog
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .pop(controller.text); // Return the new memory
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

// Function to send the initial message from the AI using a unique system message
Future<String> initialMessage() async {
  final apiKey = getOpenaiApiKey();

  final url = Uri.parse('https://api.openai.com/v1/chat/completions');
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  var messagesBody = [];
  for (var message in messages) {
    messagesBody.add(message);
  }
  messagesBody.add({
    "role": "system",
    "content":
        "Let's begin by setting the stage for an interesting conversation. Keep it concise."
  });
  final body = {"model": "gpt-4o", "messages": messagesBody};

  final response =
      await http.post(url, headers: headers, body: jsonEncode(body));
  if (response.statusCode == 200) {
    var responseBody = utf8.decode(response.bodyBytes);
    responseBody = jsonDecode(responseBody)["choices"][0]["message"]["content"];
    print("Initial GPT-4o response: $responseBody");
    return responseBody;
  } else {
    throw Exception("Failed to prompt GPT-4o for initial message");
  }
}

Future<String> updateMemory() async {
  final apiKey = getOpenaiApiKey();

  final url = Uri.parse('https://api.openai.com/v1/chat/completions');
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  var messagesBody = messages;
  messagesBody.add({
    "role": "system",
    "content":
        "You had this conversation. What should you remember about the user?\nEdit this text of your previous memories. If there is nothing new to add, just output the text again.\n$memory"
  });
  final body = {"model": "gpt-4o", "messages": messagesBody};

  final response =
      await http.post(url, headers: headers, body: jsonEncode(body));
  if (response.statusCode == 200) {
    var responseBody = utf8.decode(response.bodyBytes);
    responseBody = jsonDecode(responseBody)["choices"][0]["message"]["content"];
    print("GPT-4o response (new memory): $responseBody");
    return responseBody;
  } else {
    throw Exception("Failed to prompt GPT-4o");
  }
}

Future<String> respond() async {
  final apiKey = getOpenaiApiKey();

  final url = Uri.parse('https://api.openai.com/v1/chat/completions');
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final body = {"model": "gpt-4o", "messages": messages};

  final response =
      await http.post(url, headers: headers, body: jsonEncode(body));
  if (response.statusCode == 200) {
    var responseBody = utf8.decode(response.bodyBytes);
    responseBody = jsonDecode(responseBody)["choices"][0]["message"]["content"];
    print("GPT-4o response: $responseBody");
    return responseBody;
  } else {
    throw Exception("Failed to prompt GPT-4o");
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
  SoLoud.instance.init();
  changeVoice();
  await loadMemory();
  prepareFirstMessage();
  runApp(const MyApp());
}

Future<void> loadMemory() async {
  prefs = await SharedPreferences.getInstance();
  memory = prefs.getString('memory') ?? "";
  memory = "";
  print("loaded memory:$memory");

  String message;
  if (memory == "") {
    message =
        "This is your first interaction with this user. Start with an introduction.";
  } else {
    message =
        "From previous interactions, you know the following about the user:\n\n$memory";
  }
  messages.add({"role": "system", "content": message});
}

Future<void> prepareFirstMessage() async {
  _firstText = await initialMessage();
  _firstTts = await tts(_firstText!);
}

void say(Uint8List audio) async {
  SoundHandle soundHandle = await playAudio(audio);
  SoLoud.instance.setRelativePlaySpeed(soundHandle, 0.7);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'paragon',
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
  bool _firstMessage = true;

  void _sendMessage() async {
    String response;
    Uint8List voice;
    if (_firstMessage) {
      _firstMessage = false;
      while (_firstText == null || _firstTts == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      response = _firstText!;
      voice = _firstTts!;
    } else {
      if (_controller.text.isEmpty) return;

      final userMessage = _controller.text;
      setState(() {
        _messages.add({"role": "user", "content": userMessage});
        messages.add({"role": "user", "content": userMessage});
        _isLoading = true;
      });
      _controller.clear();

      try {
        response = await respond();
        voice = await tts(response);
      } catch (e) {
        setState(() {
          _messages.add({"role": "assistant", "content": "Error: $e"});
          _isLoading = false;
        });
        return;
      }
    }
    messages.add({"role": "assistant", "content": response});
    setState(() {
      _isLoading = false;
    });
    say(voice);
    _addMessageGradually(response, "assistant");
  }

  // Method to add message content gradually to simulate typing
  Future<void> _addMessageGradually(String content, String role) async {
    String displayedContent = content[0];
    for (int i = 1; i < content.length; i++) {
      int delay;
      switch (content[i - 1]) {
        case ',':
        case ':':
          delay = 500;
          break;
        case '!':
        case '?':
        case '.':
        case '—':
          delay = 1000;
          break;
        default:
          delay = 55;
      }
      await Future.delayed(
          Duration(milliseconds: delay)); // Delay to simulate typing
      displayedContent += content[i];
      setState(() {
        if (_messages.isNotEmpty && _messages.last["role"] == role) {
          _messages.last["content"] = displayedContent;
        } else {
          _messages.add({"role": role, "content": displayedContent});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Row(
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
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_firstMessage)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _sendMessage();
                        });
                      },
                      style: const ButtonStyle(
                          backgroundColor:
                              WidgetStatePropertyAll(Colors.white)),
                      child: Text(
                          memory.isEmpty ? "Who are you?" : "What do you want?",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          if (!_firstMessage && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          stop(context);
                        });
                      },
                      style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.grey)),
                      child: const Text("Ad beneficium omnium!",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          if (!_firstMessage && !_isLoading)
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
            )
        ],
      ),
    );
  }
}
