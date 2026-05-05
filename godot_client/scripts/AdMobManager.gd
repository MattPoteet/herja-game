extends Node

const MobilePlatform = preload("res://scripts/MobilePlatform.gd")
const AdMobConfig = preload("res://scripts/AdMobConfig.gd")

var plugin: Object
var initialized: bool = false
var banner_visible: bool = false


func _ready() -> void:
	name = "AdMobManager"
	_initialize()


func can_use_admob() -> bool:
	return MobilePlatform.is_native_app() and AdMobConfig.admob_enabled()


func show_banner() -> bool:
	if not can_use_admob() or not AdMobConfig.ADMOB_BANNER_ENABLED:
		return false
	if not _has_plugin():
		return false
	var ad_unit_id: String = AdMobConfig.banner_id()
	if ad_unit_id == "":
		return false
	banner_visible = true
	_call_plugin(["show_banner", "showBanner"], [ad_unit_id])
	return true


func hide_banner() -> void:
	if not banner_visible:
		return
	banner_visible = false
	if _has_plugin():
		_call_plugin(["hide_banner", "hideBanner"], [])


func show_interstitial() -> bool:
	if not can_use_admob() or not AdMobConfig.ADMOB_INTERSTITIAL_ENABLED:
		return false
	if not _has_plugin():
		return false
	var ad_unit_id: String = AdMobConfig.interstitial_id()
	if ad_unit_id == "":
		return false
	_call_plugin(["show_interstitial", "showInterstitial"], [ad_unit_id])
	return true


func show_rewarded() -> bool:
	if not can_use_admob() or not AdMobConfig.ADMOB_REWARDED_ENABLED:
		return false
	if not _has_plugin():
		return false
	var ad_unit_id: String = AdMobConfig.rewarded_id()
	if ad_unit_id == "":
		return false
	_call_plugin(["show_rewarded", "showRewarded"], [ad_unit_id])
	return true


func _initialize() -> void:
	if not can_use_admob():
		return
	plugin = _find_plugin()
	if plugin == null:
		print("AdMob native plugin not found. Configure a Godot AdMob plugin for Android/iOS builds.")
		return
	initialized = true
	var app_id: String = AdMobConfig.app_id()
	if app_id != "":
		_call_plugin(["configure", "set_app_id", "setAppId"], [app_id])
	_call_plugin(["initialize", "init"], [])


func _find_plugin() -> Object:
	for singleton_name in ["GodotAdMob", "AdMob", "AdmobPlugin"]:
		if Engine.has_singleton(singleton_name):
			return Engine.get_singleton(singleton_name)
	return null


func _has_plugin() -> bool:
	return initialized and plugin != null


func _call_plugin(method_names: Array[String], args: Array = []) -> void:
	if plugin == null:
		return
	for method_name in method_names:
		if plugin.has_method(method_name):
			plugin.callv(method_name, args)
			return
