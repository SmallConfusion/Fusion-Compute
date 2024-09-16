class_name Compute

class Pipeline:
	var shader: RID
	var pipeline: RID
	var uniform_set: RID

	var wgx: int
	var wgy: int
	var wgz: int

	func cleanup(rd: RenderingDevice):
		rd.free_rid(shader)
		rd.free_rid(pipeline)
		rd.free_rid(uniform_set)


var rd: RenderingDevice

var uniforms: Array[RDUniform] = []
var buffers: Array[RID] = []

var pipelines: Array[Pipeline] = []

var bound_pipeline := 0


var lock := false


static func create(shader_path: String, wg_count_x := 1, wg_count_y := 1, wg_count_z := 1) -> Compute:
	var c := Compute.new()

	c.rd = RenderingServer.create_local_rendering_device()
	c.create_pipeline(shader_path, wg_count_x, wg_count_y, wg_count_z)
	
	return c


func create_data(data: PackedByteArray) -> int:
	if lock:
		printerr("Tried to create data buffer after run")
		return -1

	var binding := len(uniforms)

	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding

	var buffer := rd.storage_buffer_create(data.size(), data)
	uniform.add_id(buffer)

	uniforms.append(uniform)
	buffers.append(buffer)

	return binding


func update_data(binding: int, data: PackedByteArray, offset := 0, size := -1) -> void:
	if size == -1:
		size = data.size()

	rd.buffer_update(buffers[binding], 0, size, data)


func get_data(binding: int, offset := 0, size := 0) -> PackedByteArray:
	return rd.buffer_get_data(buffers[binding], offset, size)


func create_image(width: int, height: int, format: RenderingDevice.DataFormat, usage_bits: int) -> int:
	if lock:
		printerr("Tried to create data buffer after run")
		return -1

	var image_format := RDTextureFormat.new()
	image_format.width = width
	image_format.height = height
	image_format.format = format
	image_format.usage_bits = usage_bits

	var binding = len(uniforms)

	var image_buffer := rd.texture_create(image_format, RDTextureView.new())

	var image_uniform := RDUniform.new()
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image_uniform.binding = binding
	image_uniform.add_id(image_buffer)

	buffers.append(image_buffer)
	uniforms.append(image_uniform)

	return binding


func update_image(binding: int, data: PackedByteArray) -> void:
	rd.texture_update(buffers[binding], 0, data)


func get_image(binding: int) -> PackedByteArray:
	return rd.texture_get_data(buffers[binding], 0)


func submit(push_bytes := PackedByteArray()) -> void:
	lock = true

	var p := pipelines[bound_pipeline]

	if not p.uniform_set:
		p.uniform_set = rd.uniform_set_create(uniforms, p.shader, 0)

	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, p.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, p.uniform_set, 0)

	if len(push_bytes) != 0:
		while push_bytes.size() % 16 != 0:
			push_bytes.append(0)

		rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())

	rd.compute_list_dispatch(compute_list, p.wgx, p.wgy, p.wgz)
	rd.compute_list_end()

	rd.submit()


func sync() -> void:
	rd.sync()


func cleanup() -> void:
	for p in pipelines:
		p.cleanup(rd)
	
	for buffer in buffers:
		rd.free_rid(buffer)
	
	rd.free()


func create_pipeline(shader_path: String, wg_count_x := 1, wg_count_y := 1, wg_count_z := 1) -> int:
	var p := Pipeline.new()
	
	p.wgx = wg_count_x
	p.wgy = wg_count_y
	p.wgz = wg_count_z

	var f := load(shader_path)
	var spirv: RDShaderSPIRV = f.get_spirv()
	p.shader = rd.shader_create_from_spirv(spirv)

	p.pipeline = rd.compute_pipeline_create(p.shader)

	pipelines.append(p)

	return len(pipelines) - 1


func bind_pipeline(pipeline_index: int) -> void:
	bound_pipeline = pipeline_index
