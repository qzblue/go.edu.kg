import 'package:url_launcher/url_launcher.dart';

void openCrispChat() => launchUrl(
      Uri.parse(
          'https://go.crisp.chat/chat/embed/?website_id=96e3a83b-5a87-439c-a247-bacb0b6406d5'),
      mode: LaunchMode.externalApplication,
    );
