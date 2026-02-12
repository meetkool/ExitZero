import 'dart:io';

/// Use this to bypass SSL certificate verification errors in development.
/// This is DANGEROUS for production. Only use in debug mode.
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
