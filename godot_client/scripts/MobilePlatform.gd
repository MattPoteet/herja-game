extends RefCounted

const MOBILE_WIDTH_THRESHOLD: int = 720
const MOBILE_HEIGHT_THRESHOLD: int = 940
const MOBILE_SAFE_MARGIN: float = 18.0
const MIN_TOUCH_TARGET: float = 54.0


static func is_native_app() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


static func is_mobile_viewport() -> bool:
	var size: Vector2i = DisplayServer.window_get_size()
	var short_side: int = min(size.x, size.y)
	var long_side: int = max(size.x, size.y)
	return short_side <= MOBILE_WIDTH_THRESHOLD and long_side <= MOBILE_HEIGHT_THRESHOLD


static func use_mobile_layout() -> bool:
	return is_native_app() or is_mobile_viewport()


static func viewport_size() -> Vector2:
	var size: Vector2i = DisplayServer.window_get_size()
	return Vector2(float(size.x), float(size.y))


static func safe_margin() -> float:
	return MOBILE_SAFE_MARGIN if use_mobile_layout() else 0.0


static func touch_target() -> float:
	return MIN_TOUCH_TARGET if use_mobile_layout() else 44.0
