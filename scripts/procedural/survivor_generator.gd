extends RefCounted
const L = preload("res://scripts/procedural/loft_mesh.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")
const Animator = preload("res://scripts/survivor_animator.gd")

static func mat(key: String) -> Material:
	return load("res://materials/upgrade/%s.tres" % key)

static func pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	root.set_script(Animator)
	root.rotation.y = deg_to_rad(145.0)
	var coat := mat("survivor_coat")
	var trim := mat("survivor_trim")
	var pants := mat("survivor_pants")
	var leather := mat("survivor_leather")
	var canvas := mat("survivor_canvas")
	var skin := mat("survivor_skin")
	var hair := mat("survivor_hair")
	var hardware := mat("painted_metal")
	var upper := pivot(root, "UpperBody", Vector3(0, 0.94, 0))
	L.add(upper, "TailoredJacket", [Vector4(-0.08, 0.20, 0.145, 0), Vector4(0.02, 0.186, 0.142, 0), Vector4(0.17, 0.207, 0.16, -0.005), Vector4(0.35, 0.253, 0.165, -0.006), Vector4(0.43, 0.222, 0.14, 0), Vector4(0.48, 0.115, 0.10, 0)], coat)
	L.rounded(upper, "StormFlap", Vector3(0.047, 0.43, 0.018), Vector3(0.018, 0.185, -0.166), trim, 0.006)
	for side in [-1, 1]:
		var collar := L.rounded(upper, "FoldedCollar", Vector3(0.10, 0.145, 0.035), Vector3(side * 0.078, 0.425, -0.108), trim)
		collar.rotation.z = side * -0.35
		L.rounded(upper, "ChestPocket", Vector3(0.115, 0.12, 0.025), Vector3(side * 0.129, 0.26, -0.164), coat)
		L.rounded(upper, "PocketFlap", Vector3(0.121, 0.035, 0.032), Vector3(side * 0.129, 0.31, -0.173), trim, 0.005)
		L.rounded(upper, "LowerPocket", Vector3(0.12, 0.115, 0.022), Vector3(side * 0.13, 0.012, -0.146), trim)
	var pelvis := pivot(root, "Pelvis", Vector3(0, 0.84, 0))
	L.add(pelvis, "Hips", [Vector4(-0.07, 0.157, 0.105, 0), Vector4(0.045, 0.18, 0.128, 0), Vector4(0.10, 0.18, 0.125, 0)], pants)
	L.add(pelvis, "Belt", [Vector4(0.07, 0.189, 0.136, 0), Vector4(0.105, 0.189, 0.136, 0)], leather)
	L.rounded(pelvis, "Buckle", Vector3(0.058, 0.042, 0.018), Vector3(0, 0.089, -0.142), hardware, 0.004)
	L.rounded(pelvis, "BeltPouch", Vector3(0.11, 0.13, 0.09), Vector3(-0.195, 0.02, 0.035), canvas)
	L.batch_static(pelvis)
	var head := pivot(upper, "Head", Vector3(0, 0.54, -0.012))
	L.add(head, "Neck", [Vector4(-0.065, 0.065, 0.065, 0), Vector4(0.015, 0.067, 0.065, 0)], skin)
	L.add(head, "FacialPlanes", [Vector4(0.015, 0.066, 0.061, -0.025), Vector4(0.045, 0.093, 0.088, -0.012), Vector4(0.105, 0.116, 0.10, 0), Vector4(0.17, 0.115, 0.102, 0.005), Vector4(0.215, 0.095, 0.09, 0.008), Vector4(0.24, 0.065, 0.06, 0.008)], skin)
	L.add(head, "CroppedHair", [Vector4(0.145, 0.118, 0.102, 0.012), Vector4(0.20, 0.112, 0.10, 0.012), Vector4(0.255, 0.06, 0.055, 0.01), Vector4(0.27, 0.025, 0.025, 0.008)], hair)
	L.rounded(head, "NoseBridge", Vector3(0.036, 0.065, 0.047), Vector3(0, 0.105, -0.105), skin, 0.008)
	L.rounded(head, "Stubble", Vector3(0.13, 0.031, 0.012), Vector3(0, 0.043, -0.092), hair, 0.006)
	for side in [-1, 1]:
		L.rounded(head, "Brow", Vector3(0.052, 0.012, 0.014), Vector3(side * 0.055, 0.136, -0.100), hair, 0.003)
		L.rounded(head, "Ear", Vector3(0.028, 0.057, 0.035), Vector3(side * 0.117, 0.105, 0), skin, 0.008)
	L.batch_static(head)
	var backpack := pivot(upper, "Backpack", Vector3(0, 0.19, 0.22))
	L.add(backpack, "CanvasPack", [Vector4(-0.24, 0.13, 0.075, 0), Vector4(-0.18, 0.178, 0.105, 0.015), Vector4(0.10, 0.17, 0.10, 0.012), Vector4(0.21, 0.125, 0.075, 0)], canvas)
	L.rounded(backpack, "Flap", Vector3(0.35, 0.13, 0.12), Vector3(0, 0.15, 0.065), trim, 0.025)
	L.rounded(backpack, "OuterPocket", Vector3(0.24, 0.17, 0.07), Vector3(0, -0.10, 0.12), canvas, 0.025)
	for side in [-1, 1]:
		L.rounded(backpack, "SidePocket", Vector3(0.085, 0.20, 0.11), Vector3(side * 0.185, -0.08, 0.015), canvas)
		L.rounded(backpack, "BuckleStrap", Vector3(0.037, 0.32, 0.014), Vector3(side * 0.085, -0.01, 0.127), leather, 0.004)
		L.rounded(backpack, "BrassBuckle", Vector3(0.05, 0.045, 0.02), Vector3(side * 0.085, 0.02, 0.139), hardware, 0.004)
		var strap := L.rounded(upper, "ShoulderStrap", Vector3(0.047, 0.42, 0.025), Vector3(side * 0.155, 0.23, -0.168), canvas, 0.008)
		strap.rotation.z = side * 0.13
	L.batch_static(backpack)
	L.batch_static(upper)
	for side in [-1, 1]:
		var prefix := "Left" if side == -1 else "Right"
		var arm := pivot(root, prefix + "Arm", Vector3(side * 0.257, 1.315, 0.005))
		L.add(arm, "UpperSleeve", [Vector4(-0.285, 0.068, 0.072, 0), Vector4(-0.20, 0.087, 0.085, 0), Vector4(-0.06, 0.101, 0.11, 0), Vector4(0.04, 0.075, 0.09, 0)], coat)
		var forearm := pivot(arm, "Forearm", Vector3(0, -0.27, 0))
		L.add(forearm, "LowerSleeve", [Vector4(-0.215, 0.052, 0.058, 0), Vector4(-0.17, 0.063, 0.068, 0), Vector4(-0.03, 0.076, 0.075, 0), Vector4(0.02, 0.067, 0.07, 0)], coat)
		L.rounded(forearm, "Cuff", Vector3(0.121, 0.045, 0.14), Vector3(0, -0.20, 0), trim)
		L.add(forearm, "Glove", [Vector4(-0.325, 0.040, 0.048, -0.015), Vector4(-0.27, 0.054, 0.052, -0.01), Vector4(-0.217, 0.048, 0.05, 0)], leather)
		L.batch_static(forearm)
		var thigh := pivot(root, prefix + "Thigh", Vector3(side * 0.115, 0.85, 0))
		L.add(thigh, "CargoThigh", [Vector4(-0.37, 0.083, 0.087, 0), Vector4(-0.28, 0.096, 0.105, 0), Vector4(-0.05, 0.113, 0.115, 0), Vector4(0.02, 0.105, 0.105, 0)], pants)
		L.rounded(thigh, "CargoPocket", Vector3(0.05, 0.16, 0.125), Vector3(side * 0.095, -0.18, 0.01), trim)
		L.rounded(thigh, "KneePad", Vector3(0.12, 0.11, 0.035), Vector3(0, -0.33, -0.087), leather)
		L.batch_static(thigh)
		var calf := pivot(root, prefix + "Calf", Vector3(side * 0.115, 0.49, 0))
		L.add(calf, "TaperedCalf", [Vector4(-0.37, 0.062, 0.063, 0), Vector4(-0.28, 0.07, 0.072, 0.005), Vector4(-0.12, 0.086, 0.082, 0.005), Vector4(0.015, 0.082, 0.08, 0)], pants)
		var boot := pivot(root, prefix + "Boot", Vector3(side * 0.115, 0, 0))
		L.add(boot, "Sole", [Vector4(0.0, 0.073, 0.138, -0.045), Vector4(0.04, 0.081, 0.145, -0.045), Vector4(0.055, 0.077, 0.14, -0.045)], leather)
		L.add(boot, "BootUpper", [Vector4(0.045, 0.075, 0.135, -0.045), Vector4(0.10, 0.073, 0.125, -0.035), Vector4(0.145, 0.069, 0.085, -0.005), Vector4(0.22, 0.063, 0.062, 0)], leather)
		L.rounded(boot, "LacePanel", Vector3(0.095, 0.045, 0.08), Vector3(0, 0.13, -0.063), trim)
		L.batch_static(boot)
	return root
