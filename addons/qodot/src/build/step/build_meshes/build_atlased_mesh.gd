class_name QodotBuildAtlasedMesh
extends QodotBuildMeshes

var atlas_material := preload("res://textures/shaders/atlas.tres") as ShaderMaterial

func get_name() -> String:
	return "atlased_mesh"

func get_type() -> int:
	return self.Type.SINGLE

func get_build_params() -> Array:
	return ['entity_properties_array', 'brush_data_dict']

func get_finalize_params() -> Array:
	return ['atlased_mesh', 'brush_data_dict', 'texture_atlas', 'inverse_scale_factor']

func get_wants_finalize():
	return true

func _run(context) -> Array:
	var brush_data_dict = context['brush_data_dict']
	var entity_properties_array = context['entity_properties_array']

	var material_names = []
	var material_index_paths = {}

	for entity_key in brush_data_dict:
		var entity_brushes = brush_data_dict[entity_key]
		var entity_properties = entity_properties_array[entity_key]

		for brush_key in entity_brushes:
			var face_data = entity_brushes[brush_key]
			var map_reader = QuakeMapReader.new()
			var brush = map_reader.create_brush(face_data)

			if not should_spawn_brush_mesh(entity_properties, brush):
				continue

			for face_idx in range(0, brush.faces.size()):
				var face = brush.faces[face_idx]
				if not should_spawn_face_mesh(entity_properties, brush, face):
					continue

				if not face.texture in material_index_paths:
					material_index_paths[face.texture] = []

				if not face.texture in material_names:
					material_names.append(face.texture)

				material_index_paths[face.texture].append([entity_key, brush_key, face_idx])

	print(material_names)

	return ["nodes", "./Meshes", [MeshInstance.new()], material_index_paths, material_names]

func _finalize(context):
	var atlased_mesh = context['atlased_mesh']
	var brush_data_dict = context['brush_data_dict']
	var texture_atlas = context['texture_atlas'][0]
	var inverse_scale_factor = context['inverse_scale_factor']

	var atlas_texture = texture_atlas[1]
	var atlas_texture_names = texture_atlas[2]
	var atlas_positions = texture_atlas[3]
	var atlas_sizes = texture_atlas[4]

	var mesh_instance = atlased_mesh[0][2][0]
	var material_index_paths = atlased_mesh[0][3]
	var material_names = atlased_mesh[0][4]

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = atlas_material.duplicate()
	material.set_shader_param('atlas', atlas_texture)
	surface_tool.set_material(material)

	var texture_rects = []

	for texture_name in atlas_texture_names:
		var texture_idx = atlas_texture_names.find(texture_name)
		var atlas_position = atlas_positions[texture_idx]
		var atlas_size = atlas_sizes[texture_idx]
		texture_rects.append([atlas_position / atlas_texture.get_size(), atlas_size / atlas_texture.get_size()])

		var texture_vertex_color = Color()
		texture_vertex_color.r = float(texture_idx) / 255.0

		if texture_name in material_index_paths:
			var face_index_paths = material_index_paths[texture_name]
			for face_index_path in face_index_paths:
				var entity_idx = face_index_path[0]
				var brush_idx = face_index_path[1]
				var face_idx = face_index_path[2]
				var face_data = brush_data_dict[entity_idx][brush_idx]

				var map_reader = QuakeMapReader.new()
				var brush = map_reader.create_brush(face_data)
				var face = brush.faces[face_idx]

				get_face_mesh(surface_tool, brush.center, face, atlas_size, texture_vertex_color, inverse_scale_factor, true)

	var rect_data_image = Image.new()
	rect_data_image.create(256, 1, false, Image.FORMAT_RGBAF)

	rect_data_image.lock()
	for texture_name in atlas_texture_names:
		var texture_idx = atlas_texture_names.find(texture_name)
		var texture_rect = texture_rects[texture_idx]
		rect_data_image.set_pixel(texture_idx, 0, Color(texture_rect[0].x, texture_rect[0].y, texture_rect[1].x, texture_rect[1].y))
	rect_data_image.unlock()

	var rect_data_texture = ImageTexture.new()
	rect_data_texture.create_from_image(rect_data_image, 0)
	material.set_shader_param('rect_data', rect_data_texture)

	mesh_instance.set_mesh(surface_tool.commit())
