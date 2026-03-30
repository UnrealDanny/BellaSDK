@tool
extends Path3D
class_name ProceduralMonkeyBars

@export_category("Dimensions")
@export var bar_width: float = 0.8:
	set(v): bar_width = max(0.2, v); if is_inside_tree(): _update_bars()

@export var rung_spacing: float = 0.4:
	set(v): rung_spacing = max(0.1, v); if is_inside_tree(): _update_bars()

@export var thickness: float = 0.05:
	set(v): thickness = max(0.01, v); if is_inside_tree(): _update_bars()

@export_category("Physics & Interaction")
@export var generate_collision_track: bool = true:
	set(v): generate_collision_track = v; if is_inside_tree(): _update_bars()
	
@export var trigger_height: float = 1.0:
	set(v): trigger_height = max(0.1, v); if is_inside_tree(): _update_bars()

var left_rail: CSGPolygon3D
var right_rail: CSGPolygon3D
var rungs: MultiMeshInstance3D
var physics_track: CSGPolygon3D
var interact_area: Area3D

func _ready() -> void:
	add_to_group("monkey_bars")
	
	if not curve:
		curve = Curve3D.new()
		curve.add_point(Vector3(0, 0, 0))
		curve.add_point(Vector3(0, 0, -3))
		
	if not curve.changed.is_connected(_update_bars):
		curve.changed.connect(_update_bars)
		
	_update_bars()

func _update_bars() -> void:
	if not is_inside_tree() or not curve or curve.get_baked_length() == 0: return

	if not left_rail:
		left_rail = CSGPolygon3D.new(); left_rail.name = "LeftRail"
		add_child(left_rail); left_rail.mode = CSGPolygon3D.MODE_PATH; left_rail.path_node = NodePath("..")
	
	if not right_rail:
		right_rail = CSGPolygon3D.new(); right_rail.name = "RightRail"
		add_child(right_rail); right_rail.mode = CSGPolygon3D.MODE_PATH; right_rail.path_node = NodePath("..")

	var t = thickness / 2.0
	var profile = PackedVector2Array([
		Vector2(-t, -t), Vector2(t, -t), Vector2(t, t), Vector2(-t, t)
	])
	
	var left_profile = PackedVector2Array()
	var right_profile = PackedVector2Array()
	for p in profile:
		left_profile.append(p + Vector2(-bar_width / 2.0, 0))
		right_profile.append(p + Vector2(bar_width / 2.0, 0))
		
	left_rail.polygon = left_profile
	right_rail.polygon = right_profile

	# --- THE TILT KILLER (RUNGS FIX) ---
	if not rungs:
		rungs = MultiMeshInstance3D.new(); rungs.name = "Rungs"
		add_child(rungs)
		var cyl = CylinderMesh.new()
		cyl.height = bar_width; cyl.top_radius = thickness / 2.0; cyl.bottom_radius = thickness / 2.0
		rungs.multimesh = MultiMesh.new()
		rungs.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		rungs.multimesh.mesh = cyl

	rungs.transform = Transform3D.IDENTITY
		
	var length = curve.get_baked_length()
	var rung_count = floor(length / rung_spacing)
	if rung_count > 0:
		rungs.multimesh.instance_count = rung_count
		for i in range(rung_count):
			var offset = (i + 0.5) * (length / rung_count)
			var trans = curve.sample_baked_with_rotation(offset)
			
			# 1. Strip Godot's random curve tilt by forcing the Up vector
			var forward = -trans.basis.z.normalized()
			var right = Vector3.UP.cross(forward).normalized()
			if right.length_squared() < 0.01: 
				right = Vector3.RIGHT # Safety fallback for perfectly vertical climbs
			var up = forward.cross(right).normalized()
			
			# 2. Rebuild the matrix so the Cylinder (Y-axis) points perfectly across the rails
			trans.basis = Basis(up, right, -forward)
			rungs.multimesh.set_instance_transform(i, trans)
	
	if generate_collision_track and physics_track:
		physics_track.transform = Transform3D.IDENTITY
		
	if interact_area:
		interact_area.transform = Transform3D.IDENTITY
		
	# --- THE IRON ROOF (PHYSICS FIX) ---
	if generate_collision_track:
		if not physics_track:
			physics_track = CSGPolygon3D.new(); physics_track.name = "PhysicsTrack"
			add_child(physics_track); physics_track.mode = CSGPolygon3D.MODE_PATH; physics_track.path_node = NodePath("..")
			var inv_mat = StandardMaterial3D.new()
			inv_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; inv_mat.albedo_color = Color(1, 1, 1, 0)
			physics_track.material = inv_mat
			
		physics_track.use_collision = true
		physics_track.collision_layer = 32 # Assign to a high, unused layer (Layer 6)
		physics_track.collision_mask = 0   # It doesn't need to "see" anything itself
		# The top corners are now 3.0 meters high to prevent the player from clipping through!
		physics_track.polygon = PackedVector2Array([
			Vector2(-bar_width/2.0, -t), Vector2(bar_width/2.0, -t), 
			Vector2(bar_width/2.0, 3.0), Vector2(-bar_width/2.0, 3.0)
		])
	elif physics_track:
		physics_track.queue_free(); physics_track = null

	if not interact_area or not is_instance_valid(interact_area):
		interact_area = get_node_or_null("InteractArea") as Area3D
		if not interact_area:
			interact_area = Area3D.new(); interact_area.name = "InteractArea"
			interact_area.collision_layer = 0; interact_area.collision_mask = 1 
			add_child(interact_area)
			if not interact_area.body_entered.is_connected(_on_body_entered):
				interact_area.body_entered.connect(_on_body_entered)
			if not interact_area.body_exited.is_connected(_on_body_exited):
				interact_area.body_exited.connect(_on_body_exited)

	if rung_count > 0:
		var current_shapes = interact_area.get_children()
		for i in range(rung_count, current_shapes.size()):
			current_shapes[i].queue_free()
			
		for i in range(rung_count):
			var shape_node: CollisionShape3D
			if i < current_shapes.size():
				shape_node = current_shapes[i] as CollisionShape3D
			else:
				shape_node = CollisionShape3D.new(); shape_node.shape = BoxShape3D.new()
				interact_area.add_child(shape_node)
				
			var offset = (i + 0.5) * (length / rung_count)
			var trans = curve.sample_baked_with_rotation(offset)
			var box = shape_node.shape as BoxShape3D
			box.size = Vector3(bar_width * 1.2, trigger_height, (length / rung_count) * 1.1)
			trans.origin -= trans.basis.y * (trigger_height / 2.0)
			shape_node.transform = trans

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint(): return 
	# THE FIX: Pass "self" so the player knows which specific path to snap to!
	if body.has_method("enter_monkey_bars"):
		body.enter_monkey_bars(self) 

func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint(): return
	if body.has_method("exit_monkey_bars"):
		body.exit_monkey_bars()
