class_name HealthBarUtil
extends RefCounted

## Green / yellow / red by fraction of max (selected-entity health bars).


static func fill_color(health_ratio: float) -> Color:
	var r := clampf(health_ratio, 0.0, 1.0)
	if r > 0.66:
		return Color(0.32, 0.92, 0.38, 0.96)
	if r > 0.33:
		return Color(0.98, 0.82, 0.22, 0.96)
	return Color(0.95, 0.3, 0.28, 0.96)


static func draw_bar(
	node: CanvasItem,
	center_x: float,
	top_y: float,
	width: float,
	height: float,
	current: float,
	max_value: float
) -> void:
	if max_value <= 0.0:
		return
	var ratio := clampf(current / max_value, 0.0, 1.0)
	var half_w := width * 0.5
	var bg := Rect2(center_x - half_w, top_y, width, height)
	node.draw_rect(bg, Color(0.06, 0.07, 0.09, 0.88), true)
	node.draw_rect(
		Rect2(center_x - half_w, top_y, width * ratio, height), fill_color(ratio), true
	)
	node.draw_rect(bg, Color(0.92, 0.94, 0.98, 0.45), false, 1.0)
