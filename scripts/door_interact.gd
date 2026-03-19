extends Node3D

@onready var animation_player: AnimationPlayer = $AnimatableBody3D/AnimationPlayer
@onready var timer: Timer = $Timer

var is_on_cooldown: bool = false

@export var open = false :
	set(v):
		if v != open:
			open = v
			update_door()

func update_door():
	if not is_node_ready():
		await ready
		
	if open:
		print("opening")
		animation_player.play("open")
	else:
		print("closing")
		animation_player.play_backwards("open")

	animation_player.set_active(true) 

func interact():
	toggle_open()

func toggle_open():
	if is_on_cooldown:
		return
		
	is_on_cooldown = true
	open = !open
	
	await get_tree().create_timer(1.0).timeout
	is_on_cooldown = false

func _on_detector_body_exited(body: Node3D) -> void:
	print("exited")
	if open and body.is_in_group("player"):
		timer.start()

func _on_detector_body_entered(body: Node3D) -> void:
	print("entered")
	if body.is_in_group("player") and not timer.is_stopped():
		timer.stop()
		
func _on_timer_timeout() -> void:
	if open:
		if not is_on_cooldown:
			is_on_cooldown = true
			open = false
			await get_tree().create_timer(1.0).timeout
			is_on_cooldown = false
		else:
			timer.start(0.5)
