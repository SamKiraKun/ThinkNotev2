import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/core/config/app_env.dart';

void main() {
  test('documents the canonical production backend API origin', () {
    expect(AppEnv.canonicalApiUrl, 'https://api.unicef.edu.eu.org');
    expect(AppEnv.canonicalApiHost, 'api.unicef.edu.eu.org');
  });

  test('API validation only accepts the canonical backend origin', () {
    expect(
      AppEnv.isCanonicalApiUri(
        Uri.parse('https://api.unicef.edu.eu.org/'),
      ),
      isTrue,
    );
    expect(
      AppEnv.isCanonicalApiUri(
        Uri.parse('https://legacy-api.example.com'),
      ),
      isFalse,
    );
    expect(
      AppEnv.isCanonicalApiUri(
        Uri.parse('https://thinknotev2.onrender.com'),
      ),
      isFalse,
    );
    expect(
      AppEnv.isCanonicalApiUri(
        Uri.parse('http://api.unicef.edu.eu.org'),
      ),
      isFalse,
    );
    expect(
      AppEnv.isCanonicalApiUri(
        Uri.parse('https://api.unicef.edu.eu.org/health'),
      ),
      isFalse,
    );
  });
}
