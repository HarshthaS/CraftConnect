// lib/screens/upload_product_voice.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class UploadProductVoice extends StatefulWidget {
  const UploadProductVoice({super.key});

  @override
  State<UploadProductVoice> createState() => _UploadProductVoiceState();
}

const String GEMINI_API_KEY = "AIzaSyDAce6bm-LRhqPmcYBJtsXCx2ypXIuChGo";

class _UploadProductVoiceState extends State<UploadProductVoice> {
  late stt.SpeechToText _speech;

  bool _speechReady = false;
  bool _isListening = false;
  bool _aiParsing = false;

  String _heard = "";
  bool _uploading = false;

  final name = TextEditingController();
  final price = TextEditingController();
  final qty = TextEditingController();
  final material = TextEditingController();
  final picker = ImagePicker();
  File? selectedImage;

  final supabase = Supabase.instance.client;


  final List<String> locales = [
    "en_US",
    "hi_IN",
    "te_IN",
    "kn_IN",
  ];


  final Map<String, List<String>> languageKeywords = {
    "en": ["price", "quantity", "material"],
    "kn": ["bele", "parimaana", "vastu"],
    "ta": ["vilai", "alavu", "porul"],
    "te": ["dhara", "parimaanam", "padartham"],
  };




  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    initSpeech();
  }

  Future<void> initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (e) {
        debugPrint("Speech init error: $e");
      },
    );

    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Microphone permission required"),
        ),
      );
    }

    setState(() {});
  }


  Future<String> shortListen(String locale) async {
    String text = "";

    await _speech.listen(
      localeId: locale,
      listenMode: stt.ListenMode.dictation,
      partialResults: false,
      cancelOnError: false,
      listenFor: const Duration(seconds: 4),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) {
        if (r.finalResult) {
          text = r.recognizedWords;
        }
      },
    );

    await Future.delayed(const Duration(seconds: 5));
    await _speech.stop();

    return text.trim();
  }


  Future<String> detectLanguage() async {
    for (final locale in locales) {
      final sample = await shortListen(locale);
      if (sample.isEmpty) continue;

      final lang = locale.split("_")[0];
      final keywords = languageKeywords[lang] ?? [];

      for (final k in keywords) {
        if (sample.toLowerCase().contains(k)) {
          return locale;
        }
      }

      if (RegExp(r'\d+').hasMatch(sample)) {
        return locale;
      }
    }

    return "en_US"; // fallback
  }


  Future<String> fullListen(String locale) async {
    String text = "";

    await _speech.listen(
      localeId: locale,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        text = result.recognizedWords;
        setState(() {
          _heard = text;
        });
      },
    );

    return text;
  }

  Future<Map<String, dynamic>?> _callGeminiForProduct(String transcript) async {
    final uri = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY",
    );


    final prompt = '''
Extract product details from this sentence.
Languages: English, Kannada, Tamil, Telugu.

Return ONLY valid JSON:
{
  "name": "",
  "price": 0,
  "quantity": 0,
  "material": ""
}

Sentence:
"$transcript"
''';

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode != 200) {
      debugPrint("Gemini error: ${response.body}");
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      final text =
      decoded["candidates"][0]["content"]["parts"][0]["text"];

      final cleaned = text
          .replaceAll("```json", "")
          .replaceAll("```", "")
          .trim();

      return jsonDecode(cleaned);
    } catch (e) {
      debugPrint("Parse error: $e");
      return null;
    }
  }






  void _fillFieldsFromGemini(Map<String, dynamic> data) {
    name.text = (data["name"] ?? "").toString().trim();
    price.text = (data["price"] ?? "").toString().trim();
    qty.text = (data["quantity"] ?? "").toString().trim();
    material.text = (data["material"] ?? "").toString().trim();
    setState(() {});
  }

  String _cleanTranscript(String input) {
    String s = input.toLowerCase();

    // remove filler words
    const fillers = [
      "uh", "um", "only", "please", "rupees", "rs", "rupay", "rupaye"
    ];

    for (final f in fillers) {
      s = s.replaceAll(RegExp(r'\b$f\b'), '');
    }

    // word numbers → digits (basic but effective)
    final Map<String, String> numbers = {
      "one": "1",
      "two": "2",
      "three": "3",
      "four": "4",
      "five": "5",
      "six": "6",
      "seven": "7",
      "eight": "8",
      "nine": "9",
      "ten": "10",
      "twenty": "20",
      "thirty": "30",
      "fifty": "50",
      "hundred": "100",
      "thousand": "1000",
    };

    numbers.forEach((word, digit) {
      s = s.replaceAll(RegExp(r'\b$word\b'), digit);
    });

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void parseAndFill(String transcript) {
    final text = transcript.toLowerCase();

    // PRICE
    final priceMatch = RegExp(
        r'(price|rupees|rs|daam|daam|bele|dhara)\s*(\d+)'
    ).firstMatch(text);

    if (priceMatch != null) {
      price.text = priceMatch.group(2)!;
    }

    // QUANTITY
    final qtyMatch = RegExp(
        r'(quantity|qty|matra|sankhye|sankhya)\s*(\d+)'
    ).firstMatch(text);

    if (qtyMatch != null) {
      qty.text = qtyMatch.group(2)!;
    }

    // MATERIAL
    final materialMatch = RegExp(
        r'(material|samaan|vastu|padartham)\s*([a-z]+)'
    ).firstMatch(text);

    if (materialMatch != null) {
      material.text = materialMatch.group(2)!;
    }

    // PRODUCT NAME
    if (text.contains("price") ||
        text.contains("daam") ||
        text.contains("bele") ||
        text.contains("dhara")) {

      name.text = text
          .split(RegExp(r'price|daam|bele|dhara'))[0]
          .trim();
    }

    setState(() {});
  }

  Future<void> parseVoiceInput(String transcript) async {
    if (transcript.isEmpty) return;

    setState(() => _aiParsing = true);
    print("Calling Gemini with transcript: $transcript");
    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY"
    );

    final prompt = """
You are an assistant for an Indian handicraft app.

The user speaks in English, Kannada, Tamil, or Telugu.
The speech may be mixed or informal.

Your job:
1. Understand the meaning
2. Translate to English if needed
3. Extract product details

Return ONLY valid JSON in this format:
{
  "name": "",
  "price": 0,
  "quantity": 0,
  "material": ""
}

Rules:
- name can be multiple words (example: clay pot, wooden toy)
- price must be a number (rupees)
- quantity must be a number
- material should be one word if possible

User speech:
"$transcript"
""";

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode != 200) {
      debugPrint("Gemini error: ${response.body}");
      setState(() => _aiParsing = false);
      return;
    }

    try {
      final decoded = jsonDecode(response.body);
      debugPrint("GEMINI RAW RESPONSE: ${response.body}");

      final text =
      decoded["candidates"][0]["content"]["parts"][0]["text"];

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1) {
        setState(() => _aiParsing = false);
        return;
      }

      final cleaned = text.substring(jsonStart, jsonEnd + 1);

      final data = jsonDecode(cleaned);

      name.text = data["name"]?.toString() ?? "";
      price.text = data["price"]?.toString() ?? "";
      qty.text = data["quantity"]?.toString() ?? "";
      material.text = data["material"]?.toString() ?? "";

    } catch (e) {
      debugPrint("Parsing failed: $e");
    }

    setState(() => _aiParsing = false);
  }






  Future<void> toggleListening() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speech engine not available")),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _heard = "Listening...";
    });

    await _speech.listen(
      localeId: "en_US",
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        final words = result.recognizedWords;

        setState(() {
          _heard = words;
        });

        if (result.finalResult && words.isNotEmpty) {
          await _speech.stop();
          setState(() => _isListening = false);

          parseAndFill(words);  // AI extraction
        }
      },
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<Map<String, String>?> uploadImageIfAvailable() async {
    if (selectedImage == null) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final fileBytes = await selectedImage!.readAsBytes();

    await supabase.storage
        .from('product_images')
        .uploadBinary(
      fileName,
      fileBytes,
      fileOptions: const FileOptions(contentType: "image/jpeg"),
    );

    final publicUrlData =
    supabase.storage.from('product_images').getPublicUrl(fileName);

    final imageUrl = publicUrlData.toString(); // ✅ FIX

    return {
      "url": imageUrl,
      "path": fileName,
    };
  }

  Future<void> uploadProduct() async {
    if (name.text.isEmpty ||
        price.text.isEmpty ||
        qty.text.isEmpty ||
        selectedImage == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields and product image are required")),
      );
      return;
    }
    setState(() => _uploading = true);
    Map<String, String>? uploadedImage = await uploadImageIfAvailable();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("products").add({
      "name": name.text.trim(),
      "price": double.tryParse(price.text) ?? 0.0,
      "quantity": int.tryParse(qty.text) ?? 0,
      "material":
      material.text.trim().isEmpty ? "Unknown" : material.text.trim(),
      "image_url": uploadedImage?["url"] ?? "",
      "image_path": uploadedImage?["path"] ?? "",

      "in_stock": (int.tryParse(qty.text) ?? 0) > 0,
      "artisan_uid": uid,
      "timestamp": FieldValue.serverTimestamp(),
    });

    setState(() => _uploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Product uploaded")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Upload"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Speak in ANY Indian language.\n"
                  "Example: \"Clay diya, price hundred rupees, quantity ten, material clay\"",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),


            ElevatedButton.icon(
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? "Stop Listening" : "Start Listening"),
              onPressed: toggleListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 8),

            if (_aiParsing)
              const Text(
                "Understanding your voice…",
                style: TextStyle(color: Colors.blueGrey),
              ),

            const SizedBox(height: 8),
            Text(
              "Heard: $_heard",
              style: const TextStyle(color: Colors.black54),
            ),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo),
                        title: const Text("Choose from Gallery"),
                        onTap: () {
                          pickImage(ImageSource.gallery);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text("Take a Photo"),
                        onTap: () {
                          pickImage(ImageSource.camera);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: selectedImage == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(selectedImage!, fit: BoxFit.cover),
                ),
              ),
            ),

            if (selectedImage != null)
              TextButton.icon(
                onPressed: () => setState(() => selectedImage = null),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  "Remove Image",
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 20),

            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: material,
              decoration: const InputDecoration(
                labelText: "Material",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),


            ElevatedButton(
              onPressed: _uploading ? null : uploadProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _uploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Upload Product"),
            ),
          ],
        ),
      ),
    );
  }
}
