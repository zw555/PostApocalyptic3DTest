extends Node3D
## Finite, pre-registered container display samples; never a separate pickup.
## Stock gates authoring records. Coordinator remains the only Mesh visibility writer.
var container: Node3D
var samples: Dictionary={}
var record_sets: Dictionary={}
var update_count:=0
func _collect(node: Node3D,parent_transform: Transform3D,buckets: Dictionary) -> void:
	var local: Transform3D=parent_transform*node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(surface)
			if not buckets.has(mat):
				buckets[mat]={"v":PackedVector3Array(),"n":PackedVector3Array(),"uv":PackedVector2Array()}
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var order: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if order.is_empty():
				for i in arrays[Mesh.ARRAY_VERTEX].size():order.append(i)
			# Expand each source index stream before combining. append_from cannot
			# safely mix indexed primitives and non-indexed procedural surfaces.
			var normal_basis:=local.basis.inverse().transposed()
			for i in order:
				buckets[mat].v.append(local*arrays[Mesh.ARRAY_VERTEX][i])
				buckets[mat].n.append((normal_basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
				buckets[mat].uv.append(arrays[Mesh.ARRAY_TEX_UV][i])
	for child in node.get_children():
		if child is Node3D:_collect(child,local,buckets)
func _display_mesh(scene: PackedScene) -> ArrayMesh:
	# One-time static batching retains original geometry, UV, normals/materials.
	# Three registered GeometryInstances replace the source child hierarchies.
	var source: Node3D=scene.instantiate()
	var buckets: Dictionary={}
	_collect(source,Transform3D.IDENTITY,buckets)
	var merged:=ArrayMesh.new()
	for mat in buckets:
		var data: Dictionary=buckets[mat]
		var arrays:=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.v
		arrays[Mesh.ARRAY_NORMAL]=data.n
		arrays[Mesh.ARRAY_TEX_UV]=data.uv
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		merged.surface_set_material(merged.get_surface_count()-1,mat)
	source.free()
	return merged
func setup(endpoint: Node3D,database: RefCounted) -> Dictionary:
	container=endpoint
	name="ItemPresentation"
	var widths: Dictionary={}
	var total:=0.0
	for id in container.inventory.contents():
		var definition: Resource=database.definition(id)
		if not definition.world_visual is PackedScene:continue
		var visual:=MeshInstance3D.new()
		visual.name="Display_"+id
		visual.set_meta("item_id",id)
		visual.mesh=_display_mesh(definition.world_visual)
		add_child(visual)
		samples[id]=visual
		widths[id]=visual.get_aabb().size.x
		total+=widths[id]
	if not samples.is_empty():total+=0.025*(samples.size()-1)
	if total>0.28:return {"ok":false,"reason":"display_does_not_fit_container"}
	var offset: float=-total/2
	for id in samples:
		var mesh: MeshInstance3D=samples[id]
		var bounds:=mesh.get_aabb()
		mesh.position=Vector3(offset+widths[id]/2-bounds.get_center().x,0.422-bounds.position.y,-bounds.get_center().z)
		offset+=widths[id]+0.025
	container.inventory.changed.connect(_stock_changed)
	return {"ok":true,"sample_count":samples.size()}
func bind_records(config: Node3D) -> void:
	for id in samples:
		var mesh: MeshInstance3D=samples[id]
		var record: Dictionary=config.records[mesh]
		# Match the existing container's GameInformation policy and height guard.
		record.root=container
		record.category="GameInformation"
		record.discovered=true
		record.information_offset=Vector3.UP*0.35
		record.structure_visible_from=[]
		record.height_reference=container
		record.height_interval=Vector2(-0.45,0.65)
		record_sets[id]=[record]
	_stock_changed(0)
func _stock_changed(_revision: int) -> void:
	update_count+=1
	for id in record_sets:
		var present: bool=container.inventory.count_item(id)>0
		for record in record_sets[id]:record.visible=present
