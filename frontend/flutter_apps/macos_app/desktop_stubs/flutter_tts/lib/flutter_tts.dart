library flutter_tts;

class FlutterTts {
  Future<bool> setLanguage(String language) async => true;

  Future<bool> setPitch(double pitch) async => true;

  Future<bool> setSpeechRate(double rate) async => true;

  Future<bool> setVolume(double volume) async => true;

  Future<dynamic> setVoice(Map<String, String> voice) async => true;

  Future<dynamic> get getVoices async => <dynamic>[];

  Future<dynamic> speak(String text) async => true;

  Future<dynamic> stop() async => true;
}
