extends ColorRect

var history: Array[float] = []
var max_points: int = 100 # How many frames to draw across the screen
var target_ms: float = 16.67 # 60 FPS target
var ceiling_ms: float = 33.33 # 30 FPS ceiling (the top of the graph)

# Explicitly typed class variables
var spectrum_seed := Vector2i.ZERO
var should_generate_spectrum: bool = true

var time: float = 0.0
var foam_grow_rate: float = 0.0
var foam_decay_rate: float = 0.0

func _process(delta: float) -> void:
	# PERFORMANCE: Don't do math if the debug menu is closed
	if not is_visible_in_tree(): 
		return

	# Convert delta (seconds) to milliseconds
	history.append(delta * 1000.0) 
	
	# Keep the array at our max size
	if history.size() > max_points:
		history.pop_front()

	# Tell Godot to trigger _draw() this frame
	queue_redraw()

func _draw() -> void:
	# Don't try to draw a shape if we don't have enough points
	if history.size() < 2: 
		return
		
	var w := size.x
	var h := size.y

	# 1. PREPARE AND DRAW THE GREEN POLYGON FIRST
	var step := w / max_points
	var points := PackedVector2Array()
	points.append(Vector2(0, h)) 

	for i in range(history.size()):
		var x := i * step
		var current_ms: float = min(history[i], ceiling_ms) 
		var y: float = h - (current_ms / float(ceiling_ms)) * h
		points.append(Vector2(x, y))

	points.append(Vector2((history.size() - 1) * step, h)) 
	if points.size() >= 2: # Polylines only need 2 points to draw a line
		draw_polyline(points, Color(0.2, 0.8, 0.2, 0.6), 2.0, true) # 2.0 is line width, true is anti-aliased

	# 2. DRAW THE YELLOW 60 FPS LINE ON TOP
	var target_y := h - (target_ms / ceiling_ms) * h
	draw_line(Vector2(0, target_y), Vector2(w, target_y), Color(1, 1, 0, 0.8), 2.0)

	# 3. DRAW THE TEXT STATUS
	# Grab the very last frame time we recorded
	var latest_ms: float = history.back() if not history.is_empty() else 0.0

	# Grab the default system font so we don't have to load a custom one
	var font := ThemeDB.fallback_font 
	var text_color := Color.GREEN
	var status_text := "16.66ms - Good"

	# If the frame took longer than our target, turn the text red and yell!
	if latest_ms > target_ms:
		text_color = Color.RED
		status_text = "16.66ms - Problem!"

	# Draw the text 5 pixels from the left, and 5 pixels above the yellow line
	var text_pos := Vector2(5, target_y - 5)

	# syntax: font, position, text, alignment, max_width, font_size, color
	draw_string(font, text_pos, status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
