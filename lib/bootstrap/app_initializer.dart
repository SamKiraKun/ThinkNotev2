import 'package:shared_preferences/shared_preferences.dart';

class AppInitializer {
	const AppInitializer();

	Future<SharedPreferences> initializePreferences() {
		return SharedPreferences.getInstance();
	}
}
