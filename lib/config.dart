import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  final String? webrtcUrl;
  final String? errorMessage;
  
  const Config._(this.webrtcUrl, this.errorMessage);
  
  bool get hasError => errorMessage != null;
  
  factory Config.create() {
    const webrtcKey = 'WEBRTC_URL';
    final webrtcEnvValue = dotenv.env[webrtcKey];
    
    if (webrtcEnvValue == null || webrtcEnvValue.isEmpty) {
      return Config._(null, '$webrtcKey not configured in .env file');
    }

    final uri = Uri.tryParse(webrtcEnvValue);
    if (uri == null || !uri.hasScheme) {
      return Config._(null, '$webrtcKey contains invalid URI: $webrtcEnvValue');
    }

    return Config._(webrtcEnvValue, null);
  }
}

final config = Config.create();