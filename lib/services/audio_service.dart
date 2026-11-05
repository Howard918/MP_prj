import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init({Function()? onTtsComplete}) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      onTtsComplete?.call();
    });
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
