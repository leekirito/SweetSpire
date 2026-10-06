extends Node2D

## Presentation-only sprites for last-seen objects outside current sight.
## These have no scripts, collision, selection, or match registry entries.
var ghosts: Dictionary = {}

func display(fog: FogOfWar, memory: Dictionary, art: Dictionary) -> void:
	var wanted: Dictionary = {}
	for id in memory.towns:
		wanted["town:%d" % int(id)] = true
	for id in memory.resources:
		var row: Dictionary = memory.resources[id]
		if not row.get("removed", false) and not memory.structures.has(str(LanCatalog.cell(row.cell))):
			wanted["resource:%d" % int(id)] = true
	for key in memory.structures:
		wanted["structure:" + key] = true
	for key in ghosts.keys():
		if not wanted.has(key) or not art.has(key):
			ghosts[key].free()
			ghosts.erase(key)
	for key in wanted:
		if not art.has(key):
			continue
		var sample: Dictionary = art[key]
		var show_memory := fog.is_cell_explored(sample.cell) and not fog.is_cell_visible(sample.cell)
		if not show_memory and not ghosts.has(key):
			continue
		var ghost: Sprite2D = ghosts.get(key)
		if ghost == null:
			ghost = Sprite2D.new()
			ghost.z_as_relative = false
			add_child(ghost)
			ghosts[key] = ghost
		ghost.visible = show_memory
		if not show_memory:
			continue
		ghost.texture = sample.texture
		ghost.global_transform = sample.transform
		ghost.offset = sample.offset
		ghost.centered = sample.centered
		ghost.flip_h = sample.flip_h
		ghost.flip_v = sample.flip_v
		ghost.hframes = sample.hframes
		ghost.vframes = sample.vframes
		ghost.frame = sample.frame
		ghost.region_enabled = sample.region_enabled
		ghost.region_rect = sample.region_rect
		ghost.z_index = sample.z
