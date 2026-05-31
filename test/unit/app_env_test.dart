import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/core/config/app_env.dart';

void main() {
  test('documents the canonical production backend API origin', () {
    expect(AppEnv.canonicalApiUrl, 'https://api.unicef.edu.eu.org');
    expect(AppEnv.canonicalApiHost, 'api.unicef.edu.eu.org');
  });

  test('normalizeApiUri remaps the retired backend host', () {
    final normalized = AppEnv.normalizeApiUri(
      Uri.parse('https://api.unicefindia.edu.eu.org/account/me?source=legacy'),
    );

    expect(
      normalized.toString(),
      'https://api.unicef.edu.eu.org/account/me?source=legacy',
    );
  });

  test('normalizeApiUri leaves active backend hosts unchanged', () {
    final normalized = AppEnv.normalizeApiUri(
      Uri.parse('https://api.unicef.edu.eu.org/account/me?source=current'),
    );

    expect(
      normalized.toString(),
      'https://api.unicef.edu.eu.org/account/me?source=current',
    );
  });

  test('production API validation only accepts the canonical backend origin',
      () {
    expect(
      AppEnv.isCanonicalProductionApiUri(
        Uri.parse('https://api.unicef.edu.eu.org/'),
      ),
      isTrue,
    );
    expect(
      AppEnv.isCanonicalProductionApiUri(
        Uri.parse('https://thinknotev2.onrender.com'),
      ),
      isFalse,
    );
    expect(
      AppEnv.isCanonicalProductionApiUri(
        Uri.parse('http://api.unicef.edu.eu.org'),
      ),
      isFalse,
    );
    expect(
      AppEnv.isCanonicalProductionApiUri(
        Uri.parse('https://api.unicef.edu.eu.org/health'),
      ),
      isFalse,
    );
  });
}
