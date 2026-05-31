import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/core/config/app_env.dart';

void main() {
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
}