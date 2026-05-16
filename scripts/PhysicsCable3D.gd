@tool # This tells Godot to run the script inside the editor!
extends Node3D
class_name PhysicsCable3D

@export_category("Cable Connections")
@export var start_anchor: Node3D
@export var end_plug: RigidBody3D 

@export_category("Physics Properties")
@export var link_scene: PackedScene 
@export var cable_length_meters: float = 3.0 
@export var link_spacing: float = 0.2

@export_category("Appearance")
@export var cable_color: Color = Color(0.1, 0.1, 0.1)
@export var thickness: float = 0.04 

var _links: Array[RigidBody3D] = []

func _ready() -> void:
	# 1. Build the Visual Path nodes (Runs in both Editor and Game)
	if not has_node("VisualPath"):
		
		_build_circular_profile(thickness)
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cable_color
		mat.roughness = 0.8

	# 2. ONLY generate physics if we are actually playing the game
	if not Engine.is_editor_hint():
		call_deferred("_generate_physics_chain")

func _generate_physics_chain() -> void:
	if not link_scene:
		printerr("CABLE ERROR: You forgot to assign the link_scene in the inspector!")
		return
		
	if not is_instance_valid(start_anchor) or not is_instance_valid(end_plug):
		return
		
	var total_links: int = int(cable_length_meters / link_spacing)
		
	if end_plug is TetheredPlug:
		end_plug.max_cable_length = cable_length_meters
		end_plug.anchor_point = start_anchor 
		
	var start_pos := start_anchor.global_position
	var end_pos := end_plug.global_position
	var previous_body: Node3D = start_anchor 
	
	var straight_dist := start_pos.distance_to(end_pos)
	var droop_amount: float = maxf(0.0, cable_length_meters - straight_dist) * 0.5
	
	for i in range(total_links):
		var link := link_scene.instantiate() as RigidBody3D
		add_child(link)
		
		for prev in _links:
			link.add_collision_exception_with(prev)
		if start_anchor is PhysicsBody3D:
			link.add_collision_exception_with(start_anchor)
		
		var fraction := float(i + 1) / float(total_links + 1)
		var drop_offset: Vector3 = Vector3.DOWN * (4.0 * droop_amount * fraction * (1.0 - fraction))
		link.global_position = start_pos.lerp(end_pos, fraction) + drop_offset
		
		if not link.global_position.is_equal_approx(previous_body.global_position):
			link.look_at(previous_body.global_position)
			
		_links.append(link)
		
		var joint := PinJoint3D.new()
		add_child(joint)
		joint.global_position = previous_body.global_position.lerp(link.global_position, 0.5)
		
		# Only assign node_a if it's an actual Physics Body
		if previous_body is PhysicsBody3D:
			joint.node_a = joint.get_path_to(previous_body)
		# If it's a Marker3D, we do nothing to node_a! 
		# Godot will pin it directly to the world at joint.global_position.
			
		joint.node_b = joint.get_path_to(link)
		
		previous_body = link

	var final_joint := PinJoint3D.new()
	add_child(final_joint)
	final_joint.global_position = previous_body.global_position.lerp(end_pos, 0.5)
	final_joint.node_a = final_joint.get_path_to(previous_body)
	final_joint.node_b = final_joint.get_path_to(end_plug)
	
	if end_plug is CollisionObject3D:
		for prev in _links:
			end_plug.add_collision_exception_with(prev)

func _build_circular_profile(t: float) -> void:
	var circle_points := PackedVector2Array()
	for i in range(8): 
		var angle := (i / 8.0) * TAU
		circle_points.append(Vector2(cos(angle), sin(angle)) * t)
