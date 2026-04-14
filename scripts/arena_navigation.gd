extends NavigationRegion2D

## Full arena mesh; in Teams mode adds a diamond hole between A2/B2 columns to push mid-lane traffic to the sides.


func _ready() -> void:
	var np := NavigationPolygon.new()
	np.add_outline(
		PackedVector2Array(
			[Vector2(0, 0), Vector2(2000, 0), Vector2(2000, 1200), Vector2(0, 1200)]
		)
	)
	if GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS:
		# Hole (opposite winding from outer box). Between mid forts Team A2 / Team B2.
		np.add_outline(
			PackedVector2Array(
				[
					Vector2(1000, 500),
					Vector2(930, 600),
					Vector2(1000, 700),
					Vector2(1070, 600),
				]
			)
		)
	np.make_polygons_from_outlines()
	navigation_polygon = np
