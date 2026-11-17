extends "res://scripts/gameplay/stage6b2a_main.gd"
const ItemPresentation=preload("res://stage_a23/scripts/container_item_presentation.gd")
var item_presentations: Array=[]
func create_structure_visibility() -> Node:
	var coordinator: Node=super.create_structure_visibility()
	# Parent assembles the original three endpoints. The coordinator has not yet
	# initialized its cache, so this uses the existing registration interface.
	for container in item_containers:
		var presentation:=ItemPresentation.new()
		container.add_child(presentation)
		var result: Dictionary=presentation.setup(container,item_database)
		if not result.ok:push_error("Item display assembly: "+result.reason)
		coordinator.config.register_object(presentation,container.zone,"content")
		presentation.bind_records(coordinator.config)
		item_presentations.append(presentation)
	return coordinator
