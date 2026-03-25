extends StaticBody3D

signal rope_broken

var health: int = 10 

func take_damage(amount: int, _dir: Vector3) -> void:
	health -= amount
	if health <= 0:
		snap_rope()

func snap_rope() -> void:
	print("Rope snapped!")
	rope_broken.emit()
	# Delete the entire Path3D root, not just the StaticBody!
	owner.queue_free()
