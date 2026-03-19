extends Area3D

@export var connect_portal: Area3D


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		var destination = connect_portal.global_transform.origin
		body.global_transform.origin = destination
