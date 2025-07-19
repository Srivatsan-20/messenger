// Conditional imports for web/mobile compatibility
// This file provides a fallback when dart:html is not available (mobile platforms)

// Stub implementation for non-web platforms
class Window {
  final LocalStorage localStorage = LocalStorage();
}

class LocalStorage {
  final Map<String, String> _storage = {};
  
  String? operator [](String key) => _storage[key];
  void operator []=(String key, String value) => _storage[key] = value;
  void remove(String key) => _storage.remove(key);
  void clear() => _storage.clear();
}

final Window window = Window();
