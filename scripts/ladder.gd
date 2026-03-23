extends Area3D

func _ready() -> void:
	# This keeps the colored box visible while you build your levels, 
	# but instantly deletes the visual mesh the exact millisecond the game starts.
	$MeshInstance3D.hide()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_ladder"):
		body.enter_ladder()

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder()
