extends RefCounted

# Real AdMob IDs should be supplied by the native app/export environment.
# Keep source defaults on test IDs/placeholders so desktop web and public repos
# never accidentally ship production ad unit IDs.
const ADMOB_ENABLED: bool = true
const ADMOB_BANNER_ENABLED: bool = true
const ADMOB_INTERSTITIAL_ENABLED: bool = true
const ADMOB_REWARDED_ENABLED: bool = true
const INTERSTITIAL_EVERY_N_LOADS: int = 10
const TEST_ADS_ENABLED: bool = true

const ANDROID_TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/6300978111"
const ANDROID_TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const ANDROID_TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
const IOS_TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/2934735716"
const IOS_TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/4411468910"
const IOS_TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/1712485313"


static func env_bool(name: String, fallback: bool) -> bool:
	var value: String = OS.get_environment(name).strip_edges().to_lower()
	if value == "":
		return fallback
	return value == "1" or value == "true" or value == "yes" or value == "on"


static func env_string(name: String, fallback: String) -> String:
	var value: String = OS.get_environment(name).strip_edges()
	return fallback if value == "" else value


static func project_bool(name: String, fallback: bool) -> bool:
	if not ProjectSettings.has_setting("herja_ads/" + name):
		return fallback
	return bool(ProjectSettings.get_setting("herja_ads/" + name, fallback))


static func project_string(name: String, fallback: String) -> String:
	if not ProjectSettings.has_setting("herja_ads/" + name):
		return fallback
	return str(ProjectSettings.get_setting("herja_ads/" + name, fallback)).strip_edges()


static func admob_enabled() -> bool:
	return env_bool("NEXT_PUBLIC_ADMOB_ENABLED", project_bool("admob_enabled", ADMOB_ENABLED))


static func test_ads_enabled() -> bool:
	return env_bool("NEXT_PUBLIC_ADMOB_TEST_MODE", project_bool("admob_test_mode", TEST_ADS_ENABLED))


static func interstitial_frequency() -> int:
	var value: int = int(OS.get_environment("NEXT_PUBLIC_ADMOB_INTERSTITIAL_EVERY_N_LOADS"))
	if value > 0:
		return max(1, value)
	var project_value: int = int(ProjectSettings.get_setting("herja_ads/admob_interstitial_every_n_loads", INTERSTITIAL_EVERY_N_LOADS))
	return max(1, project_value)


static func app_id() -> String:
	if OS.has_feature("ios"):
		return env_string("NEXT_PUBLIC_ADMOB_IOS_APP_ID", project_string("admob_ios_app_id", ""))
	return env_string("NEXT_PUBLIC_ADMOB_ANDROID_APP_ID", project_string("admob_android_app_id", ""))


static func banner_id() -> String:
	if OS.has_feature("ios"):
		return IOS_TEST_BANNER_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_IOS_BANNER_ID", project_string("admob_ios_banner_id", ""))
	return ANDROID_TEST_BANNER_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_ANDROID_BANNER_ID", project_string("admob_android_banner_id", ""))


static func interstitial_id() -> String:
	if OS.has_feature("ios"):
		return IOS_TEST_INTERSTITIAL_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_IOS_INTERSTITIAL_ID", project_string("admob_ios_interstitial_id", ""))
	return ANDROID_TEST_INTERSTITIAL_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_ANDROID_INTERSTITIAL_ID", project_string("admob_android_interstitial_id", ""))


static func rewarded_id() -> String:
	if OS.has_feature("ios"):
		return IOS_TEST_REWARDED_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_IOS_REWARDED_ID", project_string("admob_ios_rewarded_id", ""))
	return ANDROID_TEST_REWARDED_ID if test_ads_enabled() else env_string("NEXT_PUBLIC_ADMOB_ANDROID_REWARDED_ID", project_string("admob_android_rewarded_id", ""))
