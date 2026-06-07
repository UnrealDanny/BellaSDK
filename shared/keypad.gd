class_name UIKeypad
extends Control

signal code_entered(code: int)

var entered_code: String = ""

@onready var line_edit: LineEdit = $VBoxContainer/LineEdit
@onready var grid_container: GridContainer = $VBoxContainer/GridContainer


func _ready() -> void:
	print("UIKeypad: Initialization started.")
	
	for child in grid_container.get_children():
		if child is Button:
			child.pressed.connect(_on_button_pressed.bind(child.name))
			
	print("UIKeypad: Button signals connected successfully.")


func _on_button_pressed(button_name: String) -> void:
	print("UIKeypad: Button pressed -> ", button_name)

	if button_name.is_valid_int():
		if entered_code.length() < 4:
			entered_code += button_name
			line_edit.text = entered_code
			print("UIKeypad: Current code updated to -> ", entered_code)

	elif button_name == "Enter":
		print("UIKeypad: Enter button triggered.")
		_send_code()

	elif button_name == "Reset":
		entered_code = ""
		line_edit.text = ""
		print("UIKeypad: Code reset triggered.")


func _send_code() -> void:
	print("UIKeypad: Attempting to send code -> ", entered_code)
	
	if entered_code.is_valid_int():
		var final_code: int = entered_code.to_int()
		code_entered.emit(final_code)
		print("UIKeypad: Success. Code emitted -> ", final_code)
	else:
		print("UIKeypad: Failed. Code was invalid or empty.")

	entered_code = ""
	line_edit.text = ""
