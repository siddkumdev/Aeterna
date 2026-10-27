extends SceneTree
func _initialize() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	root.add_child(g)
	await process_frame
	var cs := g.decor_cells.duplicate()
	cs.sort()
	print("DECOR ", cs.size(), " ", cs)
	quit()
