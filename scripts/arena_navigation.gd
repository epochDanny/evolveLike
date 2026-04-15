extends NavigationRegion2D

## Full arena mesh; in Teams mode cuts a diamond obstruction between A2/B2 (via obstruction outline).


func _ready() -> void:
	var geo := NavigationMeshSourceGeometryData2D.new()
	geo.add_traversable_outline(
		PackedVector2Array(
			[Vector2(0, 0), Vector2(2000, 0), Vector2(2000, 1200), Vector2(0, 1200)]
		)
	)
	if GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS:
		geo.add_obstruction_outline(
			PackedVector2Array(
				[
					Vector2(1000, 500),
					Vector2(930, 600),
					Vector2(1000, 700),
					Vector2(1070, 600),
				]
			)
		)
	var np := NavigationPolygon.new()
	NavigationServer2D.bake_from_source_geometry_data(np, geo)
	navigation_polygon = np
