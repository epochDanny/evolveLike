class_name ProceduralTextures
extends Object

## Built-in Godot resources only: GradientTexture2D, NoiseTexture2D, SystemFont — no PNG imports.


static func default_ui_font() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return sf


## One stable color per fort slot (bunker + spawner + unit number tint); max 6 slots in current modes.
static func player_color_for_slot(slot: int) -> Color:
	var colors: Array[Color] = [
		Color(0.22, 0.82, 0.38),
		Color(0.95, 0.42, 0.2),
		Color(0.38, 0.52, 0.98),
		Color(0.88, 0.32, 0.72),
		Color(0.95, 0.88, 0.28),
		Color(0.35, 0.88, 0.9),
	]
	return colors[posmod(slot, colors.size())]


static func create_fort_texture(accent: Color) -> Texture2D:
	var c_top: Color = accent.lightened(0.18)
	var c_mid: Color = accent.darkened(0.12)
	var c_bot: Color = accent.darkened(0.55)
	var g := Gradient.new()
	g.add_point(0.0, c_top)
	g.add_point(0.45, c_mid)
	g.add_point(1.0, c_bot)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 176
	gt.height = 120
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	return gt


static func create_spawner_texture(accent: Color) -> Texture2D:
	var c0: Color = accent
	var c1: Color = c0.darkened(0.55)
	var g := Gradient.new()
	g.add_point(0.0, c0.lightened(0.12))
	g.add_point(0.65, c0)
	g.add_point(1.0, c1)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 56
	gt.height = 56
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(0.85, 0.5)
	return gt


## Legacy blob; units now use a colored tier Label — kept for compatibility.
static func create_unit_texture(accent: Color) -> Texture2D:
	var g := Gradient.new()
	g.add_point(0.0, accent.lightened(0.22))
	g.add_point(0.58, accent)
	g.add_point(1.0, accent.darkened(0.48))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 48
	gt.height = 48
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(0.92, 0.5)
	return gt


static func apply_ui_font_to_tree(node: Node) -> void:
	var f := default_ui_font()
	_apply_font_recursive(node, f)


static func _apply_font_recursive(n: Node, f: Font) -> void:
	if n is Label:
		(n as Label).add_theme_font_override("font", f)
	if n is Button:
		(n as Button).add_theme_font_override("font", f)
	for c in n.get_children():
		_apply_font_recursive(c, f)
