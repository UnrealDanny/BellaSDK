extends Area3D

func _ready() -> void:
	# Hides your dev-mesh just like the ladder
	$MeshInstance3D.hide()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_monkey_bars"):
		body.enter_monkey_bars()

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_monkey_bars"):
		body.exit_monkey_bars()
