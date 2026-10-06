extends RefCounted

## Per-seat last-seen static state shared by local presentation and LAN snapshots.
## Observation never changes authoritative entities or territory ownership.
var memories: Dictionary = {}
var appearances: Dictionary = {}
var resource_cells: Dictionary = {}

func view(seat: int) -> Dictionary:
	if not memories.has(seat):
		memories[seat] = {"towns": {}, "resources": {}, "structures": {}, "claims": {}}
		appearances[seat] = {}
	return memories[seat]

## Visible cells and the player's own holdings are current; other observations persist.
func observe(game: MatchManager, seat: int, visible: Dictionary) -> void:
	var memory := view(seat)
	for town: Building in game.buildings.values():
		if town.owner_id == seat or int(memory.towns.get(town.building_id, {}).get("owner", -1)) == seat or visible.has(town.current_cell):
			memory.towns[town.building_id] = {"id": town.building_id, "cell": LanCatalog.xy(town.current_cell), "owner": town.owner_id, "level": town.building_level, "exp": town.current_exp, "recruited": town.last_recruited_round}
			remember_art(seat, "town:%d" % town.building_id, town, town.sprite)
	for resource: Resources in game.resources.values():
		resource_cells[resource.resource_instance_id] = resource.current_cell
		if resource.owner_id == seat or int(memory.resources.get(resource.resource_instance_id, {}).get("owner", -1)) == seat or visible.has(resource.current_cell):
			memory.resources[resource.resource_instance_id] = {"id": resource.resource_instance_id, "cell": LanCatalog.xy(resource.current_cell), "owner": resource.owner_id, "town": resource.controlling_building_id, "upgraded": resource.is_upgraded}
			remember_art(seat, "resource:%d" % resource.resource_instance_id, resource, resource.sprite)
	for id in resource_cells:
		if not game.resources.has(id) and visible.has(resource_cells[id]):
			memory.resources[id] = {"id": id, "cell": LanCatalog.xy(resource_cells[id]), "removed": true}
	for key in memory.structures.keys():
		var cell := LanCatalog.cell(memory.structures[key].cell)
		if visible.has(cell) and not game.structure_manager.structures.has(cell):
			memory.structures.erase(key)
	for structure: Structure in game.structure_manager.structures.values():
		if visible.has(structure.current_cell):
			memory.structures[str(structure.current_cell)] = {"key": structure.data.structure_id, "cell": LanCatalog.xy(structure.current_cell), "town": structure.controlling_building_id}
			remember_art(seat, "structure:" + str(structure.current_cell), structure, structure.sprite)
	# A full remembered table includes explicit unclaimed cells, so stale claims can clear.
	var candidates: Dictionary = visible.duplicate()
	for cell: Vector2i in game.territory_manager.cell_to_building_id:
		var town := game.get_building(game.territory_manager.get_building_id_at_cell(cell))
		if town != null and town.owner_id == seat:
			candidates[cell] = true
	for cell: Vector2i in memory.claims:
		if int(memory.claims[cell].owner) == seat:
			candidates[cell] = true
	for cell: Vector2i in candidates:
		if not game.board_manager.is_cell_on_map(cell):
			continue
		var town := game.get_building(game.territory_manager.get_building_id_at_cell(cell))
		memory.claims[cell] = {"cell": LanCatalog.xy(cell), "town": town.building_id if town != null else -1, "owner": town.owner_id if town != null else -1}

## Pure visual samples are kept locally and never serialized onto the network.
func remember_art(seat: int, key: String, entity: Node2D, sprite: Sprite2D) -> void:
	if sprite == null:
		return
	var depth := sprite.z_index
	var ancestor := sprite.get_parent() as CanvasItem
	var relative := sprite.z_as_relative
	while relative and ancestor != null:
		depth += ancestor.z_index
		relative = ancestor.z_as_relative
		ancestor = ancestor.get_parent() as CanvasItem
	appearances[seat][key] = {"cell": entity.current_cell, "texture": sprite.texture, "transform": sprite.global_transform, "offset": sprite.offset, "centered": sprite.centered, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v, "hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame, "region_enabled": sprite.region_enabled, "region_rect": sprite.region_rect, "z": clampi(depth, -4096, 4096)}

## Guests import the host's knowledge after hydrating entities, including unseen memories.
func import_view(game: MatchManager, seat: int, state: Dictionary) -> void:
	memories.erase(seat)
	var memory := view(seat)
	for row: Dictionary in state.towns:
		memory.towns[int(row.id)] = row.duplicate(true)
		var town := game.get_building(int(row.id))
		if town != null:
			remember_art(seat, "town:%d" % int(row.id), town, town.sprite)
	for row: Dictionary in state.resources:
		memory.resources[int(row.id)] = row.duplicate(true)
		var resource := game.get_resource(int(row.id))
		if resource != null and not row.get("removed", false):
			remember_art(seat, "resource:%d" % int(row.id), resource, resource.sprite)
	for row: Dictionary in state.structures:
		var cell := LanCatalog.cell(row.cell)
		memory.structures[str(cell)] = row.duplicate(true)
		var structure: Structure = game.structure_manager.structures.get(cell)
		if structure != null:
			remember_art(seat, "structure:" + str(cell), structure, structure.sprite)
	for row: Dictionary in state.claims:
		memory.claims[LanCatalog.cell(row.cell)] = row.duplicate(true)
