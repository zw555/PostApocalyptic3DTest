extends RefCounted
## Endpoints implement can_interact, interaction_prompt, perform, rank, stable_id.
## Priority first (doors before containers), then distance, then stable ID.
var endpoints: Array = []
var displayed_target: Object
var displayed_prompt := ""
var execution_count := 0
func select(context: Dictionary) -> Object:
	var selected: Object
	var best: Array = []
	for endpoint in endpoints:
		if not endpoint.can_interact(context): continue
		var rank: Array = endpoint.rank(context)
		if selected == null or rank[0] < best[0] or rank[0] == best[0] and (rank[1] < best[1]-0.00001 or is_equal_approx(rank[1],best[1]) and endpoint.stable_id() < selected.stable_id()):
			selected = endpoint
			best = rank
	return selected
func refresh(context: Dictionary) -> void:
	displayed_target = select(context)
	displayed_prompt = "" if displayed_target == null else displayed_target.interaction_prompt(context)
func execute_displayed(context: Dictionary) -> Dictionary:
	# Never silently retarget between the displayed hint and input event.
	var selected := select(context)
	if displayed_target == null or selected != displayed_target or not displayed_target.can_interact(context):
		refresh(context)
		return {"ok":false,"reason":"target_changed","actual_quantity":0}
	execution_count += 1
	var result: Dictionary = displayed_target.perform(context)
	result.target_id = displayed_target.stable_id()
	refresh(context)
	return result
