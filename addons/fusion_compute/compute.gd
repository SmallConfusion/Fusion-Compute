class_name Compute
## Compute shader helper.
##
## When creating data buffers or images, they should be created in binding
## order, as the first one created will be binding = 0, the second one will be
## binding = 1, and so on.


class _Pipeline:
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


var _rd: RenderingDevice

var _uniforms: Array[RDUniform] = []
var _buffers: Array[RID] = []
var _pipelines: Array[_Pipeline] = []

var _lock := false


## Creates an instance of Compute.
##
## Use this function rather than Compute.new(), as this runs necessary
## initialization steps. wg_count_x, y, and z are the number of groups that this
## compute shader is dispatched on. use_global_rd uses the global rendering
## device rather than creating a local one. I don't know the consequences of
## this but it allows you to use a Texture2DRD.
static func create(
			shader_path: String,
			wg_count_x := 1,
			wg_count_y := 1,
			wg_count_z := 1,
			use_global_rd := false
		) -> Compute:

	var c := Compute.new()

	if use_global_rd:
		c._rd = RenderingServer.get_rendering_device()
	else:
		c._rd = RenderingServer.create_local_rendering_device()

	c.create_pipeline(shader_path, wg_count_x, wg_count_y, wg_count_z)
	
	return c


## Changes the work group count on a pipeline. The default pipeline is 0.
func update_wg_count(
				wg_count_x := 1,
				wg_count_y := 1,
				wg_count_z := 1,
				pipeline := 0
			) -> void:

	_pipelines[pipeline].wgx = wg_count_x
	_pipelines[pipeline].wgy = wg_count_y
	_pipelines[pipeline].wgz = wg_count_z


## Creates a data buffer from the provided PackedByteArray. It returns the
## binding that this buffer is on.
func create_data(data: PackedByteArray) -> int:
	if _lock:
		printerr("Tried to create data buffer after run")
		return -1

	var binding := len(_uniforms)

	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding

	var buffer := _rd.storage_buffer_create(data.size(), data)
	uniform.add_id(buffer)

	_uniforms.append(uniform)
	_buffers.append(buffer)

	return binding


## Updates data on the provided buffer.
func update_data(
				binding: int,
				data: PackedByteArray,
				offset := 0,
				size := -1
			) -> void:

	if size == -1:
		size = data.size()

	_rd.buffer_update(_buffers[binding], 0, size, data)


## Gets the data from the provided buffer.
func get_data(binding: int, offset := 0, size := 0) -> PackedByteArray:
	return _rd.buffer_get_data(_buffers[binding], offset, size)


## Initializes an image. This function does not assign anything to this image,
## update_image() should be called after this to provide image data. Returns the
## binding that this image was created on.
func create_image(
				width: int,
				height: int,
				format: RenderingDevice.DataFormat,
				usage_bits: int
			) -> int:

	if _lock:
		printerr("Tried to create data buffer after run")
		return -1

	var image_format := RDTextureFormat.new()
	image_format.width = width
	image_format.height = height
	image_format.format = format
	image_format.usage_bits = usage_bits

	var binding = len(_uniforms)

	var image_buffer := _rd.texture_create(image_format, RDTextureView.new())

	var image_uniform := RDUniform.new()
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image_uniform.binding = binding
	image_uniform.add_id(image_buffer)

	_buffers.append(image_buffer)
	_uniforms.append(image_uniform)

	return binding


## Initializes an image with the provided format. This function does not assign
## anything to this image, update_image() should be called after this to provide
## image data. Returns the binding that this image was created on.
func create_image_from_format(format: RDTextureFormat) -> int:
	if _lock:
		printerr("Tried to create data buffer after run")
		return -1

	var binding = len(_uniforms)

	var image_buffer := _rd.texture_create(format, RDTextureView.new())

	var image_uniform := RDUniform.new()
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image_uniform.binding = binding
	image_uniform.add_id(image_buffer)

	_buffers.append(image_buffer)
	_uniforms.append(image_uniform)

	return binding


## Updates image data on the provided binding.
func update_image(binding: int, data: PackedByteArray) -> void:
	_rd.texture_update(_buffers[binding], 0, data)


## Gets the image data from the provided binding.
func get_image(binding: int) -> PackedByteArray:
	return _rd.texture_get_data(_buffers[binding], 0)


## Clears the image data on the provided binding.
func clear_image(binding: int, color: Color) -> void:
	_rd.texture_clear(_buffers[binding], color, 0, 1, 0, 1)


## Returns the rid of the image on the provided binding, for use with a
## Texture2DRD. Make sure that this compute object was created with
## use_global_rd = true, otherwise this will not work.
func get_image_rid(binding: int) -> RID:
	return _buffers[binding]


## Submits the compute shader on a given pipeline, the default pipeline is 0.
## If a PackedByteArray of your push constants is provided, they will be passed
## to the shader.
func submit(push_constant := PackedByteArray(), pipeline := 0) -> void:
	_lock = true

	var p := _pipelines[pipeline]

	if not p.uniform_set.is_valid():
		p.uniform_set = _rd.uniform_set_create(_uniforms, p.shader, 0)

	var compute_list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, p.pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, p.uniform_set, 0)

	if len(push_constant) != 0:
		while push_constant.size() % 16 != 0:
			push_constant.append(0)

		_rd.compute_list_set_push_constant(
				compute_list,
				push_constant,
				push_constant.size()
			)

	_rd.compute_list_dispatch(compute_list, p.wgx, p.wgy, p.wgz)
	_rd.compute_list_end()

	_rd.submit()


## Syncs the shader.
func sync() -> void:
	_rd.sync()


## Performs cleanup, freeing data from the gpu. This should be called when
## you're finished with the Compute object, to avoid memory leaks.
func cleanup() -> void:
	for p in _pipelines:
		p.cleanup(_rd)
	
	for buffer in _buffers:
		_rd.free_rid(buffer)
	
	_rd.free()


## Creates another pipeline on this Compute object. Buffers are shared between
## all pipelines.
func create_pipeline(shader_path: String, wg_count_x := 1, wg_count_y := 1, wg_count_z := 1) -> int:
	var p := _Pipeline.new()
	
	p.wgx = wg_count_x
	p.wgy = wg_count_y
	p.wgz = wg_count_z

	var f := load(shader_path)
	var spirv: RDShaderSPIRV = f.get_spirv()
	p.shader = _rd.shader_create_from_spirv(spirv)

	p.pipeline = _rd.compute_pipeline_create(p.shader)

	_pipelines.append(p)

	return len(_pipelines) - 1
