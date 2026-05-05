extends Resource
class_name ChapterData

@export var chapter_name: String
@export_multiline var description: String
@export var image: Texture2D
@export_file("*.scn", "*.tscn") var scene_path: String
