extends Node
class_name TweenManager

# Central Tween Manager for Journey Mode
# Provides pooled, labeled tween creation with deduplication and accessibility-friendly defaults.

# Configuration
var default_ease := Tween.EASE_OUT
var default_trans := Tween.TRANS_QUAD
var max_pool_size := 64

# Optional per-label overrides (ease, trans) and preset durations
var _label_overrides: Dictionary = {} # label -> {"ease": Tween.EaseType, "trans": Tween.TransitionType}
var _presets: Dictionary = {
	"fast": 0.2,
	"normal": 0.4,
	"slow": 0.8
}

# Internal pools
var _active_tweens: Array[Tween] = []
var _labeled_tweens := {}

func _init():
	print("TweenManager: Initialized")

func _process(_delta):
	# Clean finished tweens each frame (lightweight)
	for t in _active_tweens.duplicate():
		if !is_instance_valid(t) or t.is_valid() == false:
			_active_tweens.erase(t)
			continue
		if t.is_running() == false:
			_active_tweens.erase(t)

func create(label: String = "", replace: bool = true) -> Tween:
	# Optionally replace existing labeled tween
	if label != "":
		if replace and _labeled_tweens.has(label):
			var old: Tween = _labeled_tweens[label]
			if is_instance_valid(old):
				old.kill() # stop gracefully
			_labeled_tweens.erase(label)
		elif !replace and _labeled_tweens.has(label):
			return _labeled_tweens[label]
	var tween: Tween = get_tree().create_tween()
	if label != "" and _label_overrides.has(label):
		var cfg = _label_overrides[label]
		var ease_val = cfg.get("ease", default_ease)
		var trans_val = cfg.get("trans", default_trans)
		tween.set_trans(trans_val).set_ease(ease_val)
	else:
		tween.set_trans(default_trans).set_ease(default_ease)
	_active_tweens.append(tween)
	if label != "":
		_labeled_tweens[label] = tween
	_trim_pool()
	return tween

func sequence(label: String = "", replace: bool = true) -> Tween:
	var t = create(label, replace)
	return t.set_parallel(false)

func parallel(label: String = "", replace: bool = true) -> Tween:
	var t = create(label, replace)
	return t.set_parallel(true)

func kill(label: String):
	if _labeled_tweens.has(label):
		var t: Tween = _labeled_tweens[label]
		if is_instance_valid(t):
			t.kill()
		_labeled_tweens.erase(label)

func kill_all():
	for t in _active_tweens:
		if is_instance_valid(t):
			t.kill()
	_active_tweens.clear()
	_labeled_tweens.clear()

func has(label: String) -> bool:
	return _labeled_tweens.has(label)

func _trim_pool():
	if _active_tweens.size() <= max_pool_size:
		return
	# Remove oldest finished tweens first
	for t in _active_tweens.duplicate():
		if _active_tweens.size() <= max_pool_size:
			break
		if !is_instance_valid(t) or t.is_running() == false:
			_active_tweens.erase(t)
	# If still too many, force kill oldest running
	while _active_tweens.size() > max_pool_size:
		var victim = _active_tweens.pop_front()
		if is_instance_valid(victim):
			victim.kill()

# Convenience helpers
func fade_in(node: CanvasItem, duration := 0.35, label: String = ""):
	if !is_instance_valid(node):
		return null
	var t = create(label)
	var start_a = node.modulate.a
	if start_a < 0.01:
		node.modulate.a = 0.0
	return t.tween_property(node, "modulate:a", 1.0, duration)

func fade_out(node: CanvasItem, duration := 0.35, label: String = ""):
	if !is_instance_valid(node):
		return null
	var t = create(label)
	return t.tween_property(node, "modulate:a", 0.0, duration)

func scale_pop(node: Node2D, duration := 0.35, from := Vector2(0.8, 0.8), to := Vector2(1, 1), label: String = ""):
	if !is_instance_valid(node):
		return null
	node.scale = from
	var t = create(label)
	t.tween_property(node, "scale", to, duration)
	return t

# Per-label override API
func set_label_override(label: String, ease_value: int = default_ease, trans_value: int = default_trans):
	_label_overrides[label] = {"ease": ease_value, "trans": trans_value}

func clear_label_override(label: String):
	if _label_overrides.has(label):
		_label_overrides.erase(label)

func clear_all_overrides():
	_label_overrides.clear()

func get_preset_duration(preset_key: String, fallback: float = 0.4) -> float:
	return _presets.get(preset_key, fallback)

func set_preset(preset_key: String, duration: float):
	_presets[preset_key] = duration
