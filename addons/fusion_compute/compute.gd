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


## Creates an instance of Compute. Use this function rather than .new(), as this runs necessary initialization steps
static func create(shader_path: String, wg_count_x := 1, wg_count_y := 1, wg_count_z := 1) -> Compute:
	var c := Compute.new()

	c.rd = RenderingServer.create_local_rendering_device()
	c.create_pipeline(shader_path, wg_count_x, wg_count_y, wg_count_z)
	
	return c


## Creates a data buffer from the provided PackedByteArray. It returns the binding that this buffer is on.
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


## Updates data on the provided buffer.
func update_data(binding: int, data: PackedByteArray, offset := 0, size := -1) -> void:
	if size == -1:
		size = data.size()

	rd.buffer_update(buffers[binding], 0, size, data)


## Gets the data from the provided buffer.
func get_data(binding: int, offset := 0, size := 0) -> PackedByteArray:
	return rd.buffer_get_data(buffers[binding], offset, size)


## Initializes an image. This function does not assign anything to this image, update_image() shoudl be called after this to provide image data. Returns the binding that this image was created on.
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


## Updates image data on the provided binding.
func update_image(binding: int, data: PackedByteArray) -> void:
	rd.texture_update(buffers[binding], 0, data)


## Gets the image data from the provided binding.
func get_image(binding: int) -> PackedByteArray:
	return rd.texture_get_data(buffers[binding], 0)


## Submits the compute shader.
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


## Syncs the shader.
func sync() -> void:
	rd.sync()


## Performs cleanup, freeing data from the gpu. This should be called when you're done with the Compute object, to avoid memory leaks.
func cleanup() -> void:
	for p in pipelines:
		p.cleanup(rd)
	
	for buffer in buffers:
		rd.free_rid(buffer)
	
	rd.free()


## Creates another pipeline on this Compute object. Buffers are shared between all pipelines.
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


## Preps the pipeline for use. This function runs nothing, use submit() after setting the pipeline to run the pipeline.
func bind_pipeline(pipeline_index: int) -> void:
	bound_pipeline = pipeline_index
