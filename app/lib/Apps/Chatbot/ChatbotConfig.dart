import 'package:threebotlogin/helpers/EnvConfig.dart';
import 'package:threebotlogin/helpers/Environment.dart';

class ChatbotConfig extends EnvConfig {
  ChatbotConfigImpls impl;

  ChatbotConfig() {
    if (environment == Environment.Staging) {
      impl = ChatbotConfigStaging();
    } else if (environment == Environment.Production) {
      impl = ChatbotConfigProduction();
    } else if (environment == Environment.Local) {
      impl = ChatbotConfigLocal();
    }
  }

  String url() {
    return impl.url();
  }
}

abstract class ChatbotConfigImpls {
  String url();
}

class ChatbotConfigStaging extends ChatbotConfigImpls {
  String url() {
    return 'https://go.crisp.chat/chat/embed/?website_id=1a5a5241-91cb-4a41-8323-5ba5ec574da0&&user_email=';
  }
}

class ChatbotConfigProduction extends ChatbotConfigImpls {
  String url() {
    return 'https://go.crisp.chat/chat/embed/?website_id=1a5a5241-91cb-4a41-8323-5ba5ec574da0';
  }
}

class ChatbotConfigLocal extends ChatbotConfigImpls {
  String url() {
    return 'https://go.crisp.chat/chat/embed/?website_id=1a5a5241-91cb-4a41-8323-5ba5ec574da0';
  }
}
