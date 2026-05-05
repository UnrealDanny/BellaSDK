extends CanvasLayer

# Save this as InGameConsole.gd
# IMPORTANT: Go to Project -> Project Settings -> Autoload, and add this script with the Node Name "Console".

var output_log: RichTextLabel
var panel: PanelContainer
var vbox: VBoxContainer
var command_input: LineEdit

# --- NEW: Message Cache ---
var message_history: Array[Dictionary] = []
var is_ui_ready: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128 
	visible = false 
	
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -450 
	add_child(panel)

	vbox = VBoxContainer.new()
	panel.add_child(vbox)

	output_log = RichTextLabel.new()
	output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_log.scroll_following = true
	output_log.selection_enabled = true
	output_log.bbcode_enabled = true
	output_log.add_theme_constant_override("margin_left", 10)
	output_log.add_theme_constant_override("margin_top", 10)
	vbox.add_child(output_log)

	command_input = LineEdit.new()
	command_input.placeholder_text = "Type a command..."
	command_input.text_submitted.connect(_on_command_submitted) 
	vbox.add_child(command_input)

	# --- NEW: Mark UI as ready and flush the history ---
	is_ui_ready = true
	
	# Dump any messages that were sent during game startup
	for msg in message_history:
		output_log.append_text("[color=" + msg["color"] + "]" + msg["text"] + "[/color]\n")

	write("Developer console initialized. Press ~ to toggle.", "cyan")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console"):
		visible = !visible
		
		if visible:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			command_input.grab_focus() 
			command_input.clear()
		else:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		get_viewport().set_input_as_handled() 

# --- LOGGING ---

func write(message: String, color: String = "white") -> void:
	print(message) 
	
	# Cache the message safely
	message_history.append({"text": message, "color": color})
	
	# If the UI exists, print it. If not, it stays in the history to be printed later!
	if is_ui_ready and output_log:
		output_log.append_text("[color=" + color + "]" + message + "[/color]\n")

func log_info(msg: String) -> void:
	write(msg, "lightgray")

func log_warn(msg: String) -> void:
	write("[WARNING] " + msg, "yellow")

func log_error(msg: String) -> void:
	write("[ERROR] " + msg, "red")

# --- COMMAND PARSING ---

func _on_command_submitted(text: String) -> void:
	command_input.clear() 
	
	var clean_text := text.strip_edges()
	if clean_text == "":
		return 
		
	write("> " + clean_text, "darkgray")
	
	var parts := clean_text.split(" ")
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	
	_process_command(command, args)

func _process_command(cmd: String, _args: PackedStringArray) -> void:
	match cmd:
		"help":
			write("Available commands: help, clear, noclip, iddqd, quit", "green")
		"clear":
			output_log.clear()
			message_history.clear() 
			write("Console cleared.", "cyan")
		"quit":
			write("Exiting game...", "red")
			get_tree().quit()
		"noclip":
			Events.noclip_ui_button_pressed.emit()
			write("Toggled Noclip.", "yellow")
		"iddqd":
			# The classic Doom cheat!
			write("good memory!", "gold")
		"idkfa":
			write("another classic", "gold")
		"kirov":
			write("Kirov reporting!", "red")
		"sv_cheats":
			# Check if the user provided the "1" argument
			if _args.size() > 0 and _args[0] == "1":
				write("You don't need it. God has given us enough impulse this time", "white")
			else:
				write("Usage: sv_cheats 1", "red")
		"soyuz":
			write("Nerushimuy!")
		"motherlode":
			write("This is a classic get-rich-quick scheme! You're being arrested!")
		"konami":
			write("Fuck Konami and thank god for Jimbo")
		"upupdowndownleftrightleftrightbastart":
			write("30 lives to this miss!")
			#add 30 hearts later
		"showmethemoney":
			write("All I have is 10 bucks")
		"thereisnocowlevel":
			write("There is none! I swear!")
		"whosyourdaddy":
			write("DannyDeTour, bitch")
		"dnkroz":
			write("You're an inspiration for birth control.")
			#give godmode
		"hesoyam":
			write("What's up, homie?")
		"leavemealone":
			write("Tommy! Remember the good old times?!")
		"impulse":
			# Check if the user provided the "1" argument
			if _args.size() > 0 and _args[0] == "101":
				write("Bella doesn't need to hear about safety preconscious`. She's a highly trained professional", "white")
			else:
				write("Usage: sv_cheats 1", "red")
		"thegodfather":
			write("do not care")
		_:
			write("Unknown command: '" + cmd + "'. Type 'help' for a list.", "red")
