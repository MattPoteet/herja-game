extends CanvasLayer

signal ad_break_started
signal ad_break_finished

const AdMobConfig = preload("res://scripts/AdMobConfig.gd")
const MobilePlatform = preload("res://scripts/MobilePlatform.gd")

const LOADS_PER_AD: int = 10
const MIN_SECONDS_BEFORE_CONTINUE: float = 3.0
const FALLBACK_AD_SECONDS: float = 8.0

var load_screen_count: int = 0
var ad_active: bool = false
var continue_enabled: bool = false
var admob_manager: Node

var dim: ColorRect
var panel: Panel
var title_label: Label
var body_label: Label
var countdown_label: Label
var continue_button: Button


func _ready() -> void:
	layer = 120
	_build_ui()
	visible = false


func setup(native_admob_manager: Node = null) -> void:
	admob_manager = native_admob_manager


func should_show_for_next_load() -> bool:
	load_screen_count += 1
	var frequency: int = AdMobConfig.interstitial_frequency() if MobilePlatform.is_native_app() else LOADS_PER_AD
	return load_screen_count % frequency == 0


func show_ad_break() -> void:
	if ad_active:
		return
	ad_active = true
	continue_enabled = false
	_update_continue_button()
	ad_break_started.emit()

	if _try_request_native_interstitial():
		await get_tree().create_timer(1.0).timeout
		ad_active = false
		ad_break_finished.emit()
		return

	visible = true
	_try_request_web_interstitial()
	await _run_fallback_ad_timer()

	ad_active = false
	visible = false
	ad_break_finished.emit()


func _build_ui() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	panel = Panel.new()
	if MobilePlatform.use_mobile_layout():
		var viewport: Vector2 = MobilePlatform.viewport_size()
		var margin: float = MobilePlatform.safe_margin()
		panel.position = Vector2(margin, max(margin, viewport.y * 0.30))
		panel.size = Vector2(viewport.x - margin * 2.0, 330)
	else:
		panel.position = Vector2(390, 210)
		panel.size = Vector2(500, 290)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.10, 0.98), Color(0.86, 0.72, 0.40), 10))
	add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(24, 22)
	root.size = panel.size - Vector2(48, 44)
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	title_label = Label.new()
	title_label.text = "Sponsored Break"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30 if MobilePlatform.use_mobile_layout() else 26)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68))
	root.add_child(title_label)

	body_label = Label.new()
	body_label.text = "Map travel is paused while this message is shown. Enemies cannot move or attack during ad breaks."
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 16 if MobilePlatform.use_mobile_layout() else 14)
	body_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	root.add_child(body_label)

	countdown_label = Label.new()
	countdown_label.text = ""
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Color(0.74, 0.82, 0.92))
	root.add_child(countdown_label)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(0, 58) if MobilePlatform.use_mobile_layout() else Vector2(0, 42)
	continue_button.pressed.connect(_on_continue_pressed)
	root.add_child(continue_button)


func _run_fallback_ad_timer() -> void:
	var elapsed: float = 0.0
	while ad_active and elapsed < FALLBACK_AD_SECONDS:
		var remaining: float = max(0.0, FALLBACK_AD_SECONDS - elapsed)
		if elapsed < MIN_SECONDS_BEFORE_CONTINUE:
			countdown_label.text = "Continue available in %d..." % int(ceil(MIN_SECONDS_BEFORE_CONTINUE - elapsed))
		else:
			continue_enabled = true
			countdown_label.text = "Continuing in %d..." % int(ceil(remaining))
		_update_continue_button()
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25


func _on_continue_pressed() -> void:
	if not continue_enabled:
		return
	ad_active = false


func _update_continue_button() -> void:
	if continue_button == null:
		return
	continue_button.disabled = not continue_enabled


func _try_request_web_interstitial() -> void:
	if not OS.has_feature("web"):
		return
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval("if (window.herjaShowInterstitial) { window.herjaShowInterstitial(); }", true)


func _try_request_native_interstitial() -> bool:
	if not MobilePlatform.is_native_app():
		return false
	if admob_manager == null or not admob_manager.has_method("show_interstitial"):
		return false
	return bool(admob_manager.call("show_interstitial"))


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
