class_name Compute
## Compute shader helper.
##
## When creating data buffers or images, they should be created in binding
## order, as the first one created will be binding = 0,
## the second one will be binding = 1, and so on.

var _rd: RenderingDevice

var _uniforms: Array[RDUniform] = []
var _buffers: Array[_Buffer] = []
var _pipelines: Array[_Pipeline] = []

var _uses_global_rd: bool
var _lock := false

## Creates an instance of [Compute].[br]
##
## [param wg_count_x], [param y], and [param z] are the number of groups that
## this compute shader is dispatched on.[br]
##
## [param use_global_rd] uses the global rendering device rather than creating
## a local one. This  allows you to use a [Texture2DRD]. Because of things
## under the hood, sync should not be called and submit doesn't actually
## call submit on the underlying rendering device, only sets up the compute
## list, since only local devices can submit and sync.
func _init(
			shader_path: String,
			wg_count_x := 1,
			wg_count_y := 1,
			wg_count_z := 1,
			use_global_rd := false,
		) -> void:
	_uses_global_rd = use_global_rd

	if use_global_rd:
		_rd = RenderingServer.get_rendering_device()
	else:
		_rd = RenderingServer.create_local_rendering_device()
	
	create_pipeline(shader_path, wg_count_x, wg_count_y, wg_count_z)
	
## Creates a new [Compute] object.
## @deprecated: Use `Compute.new()` instead.
static func create(
			shader_path: String,
			wg_count_x := 1,
			wg_count_y := 1,
			wg_count_z := 1,
			use_global_rd := false
		) -> Compute:

	return Compute.new(
			shader_path,
			wg_count_x,
			wg_count_y,
			wg_count_z,
			use_global_rd
		)

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

## Creates a data buffer from the provided [PackedByteArray]. It returns the
## binding that this buffer is on.
func create_data(data: PackedByteArray) -> int:
	assert(!_lock, "Attempted to create new data buffer after running.")

	var binding := len(_uniforms)

	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding

	var buffer := _Buffer.new()
	buffer.type = _Buffer.Usage.DATA

	buffer.rid = _rd.storage_buffer_create(data.size(), data)
	uniform.add_id(buffer.rid)

	_buffers.append(buffer)
	_uniforms.append(uniform)

	return binding

## Updates data on the provided buffer.
func update_data(
				binding: int,
				data: PackedByteArray,
				offset := 0,
				size := -1
			) -> void:
	
	_validate_binding(binding, _Buffer.Usage.DATA)
	
	if size == -1:
		size = data.size()

	_rd.buffer_update(_buffers[binding].rid, 0, size, data)

## Gets the data from the provided buffer.
func get_data(binding: int, offset := 0, size := 0) -> PackedByteArray:
	_validate_binding(binding, _Buffer.Usage.DATA)
	return _rd.buffer_get_data(_buffers[binding].rid, offset, size)

## Initializes an image.[br]
##
## This function does not assign anything to this image,
## [member update_image()] should be called after this to provide image data. Returns the
## binding that this image was created on.
func create_image(
				width: int,
				height: int,
				format: RenderingDevice.DataFormat,
				usage_bits: int
			) -> int:

	var image_format := RDTextureFormat.new()
	image_format.width = width
	image_format.height = height
	image_format.format = format
	image_format.usage_bits = usage_bits

	return create_image_from_format(image_format)

## Initializes an image with the provided format.[br]
##
## This function does not assign
## anything to this image, [member update_image()] should be called after this
## to provide image data. Returns the binding that this image was created on.
func create_image_from_format(format: RDTextureFormat) -> int:
	assert(!_lock, "Attempted to create new image buffer after running.")

	var binding = len(_uniforms)

	var buffer := _Buffer.new()

	buffer.type = _Buffer.Usage.IMAGE

	buffer.rid = _rd.texture_create(format, RDTextureView.new())

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(buffer.rid)

	_buffers.append(buffer)
	_uniforms.append(uniform)

	return binding

## Updates image data on the provided binding.
func update_image(binding: int, data: PackedByteArray) -> void:
	_validate_binding(binding, _Buffer.Usage.IMAGE)
	_rd.texture_update(_buffers[binding].rid, 0, data)

## Gets the image data from the provided binding.
func get_image(binding: int) -> PackedByteArray:
	_validate_binding(binding, _Buffer.Usage.IMAGE)
	return _rd.texture_get_data(_buffers[binding].rid, 0)

## Clears the image data on the provided binding.
func clear_image(binding: int, color: Color) -> void:
	_validate_binding(binding, _Buffer.Usage.IMAGE)
	_rd.texture_clear(_buffers[binding].rid, color, 0, 1, 0, 1)

## Returns the rid of the image on the provided binding, for use with a
## [Texture2DRD]. Make sure that this compute object was created with
## [code]use_global_rd = true[/code], otherwise this will not work. Reminder
## that in this case `Compute.sync()` should not be called.
func get_image_rid(binding: int) -> RID:
	_validate_binding(binding, _Buffer.Usage.IMAGE)

	assert(
			_uses_global_rd,
			"Compute needs to be created with use_global_rd = true to use get_image_rid()"
		)

	return _buffers[binding].rid

## Submits the compute shader on a given pipeline, the default pipeline is 0.
## If a [PackedByteArray] or [Array] of your push constants is provided, they will be
## passed to the shader.
func submit(push_constant: Variant = PackedByteArray(), pipeline := 0) -> void:
	_lock = true

	var p := _pipelines[pipeline]

	if not p.uniform_set.is_valid():
		p.uniform_set = _rd.uniform_set_create(_uniforms, p.shader, 0)

	var compute_list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, p.pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, p.uniform_set, 0)

	var computed_pc: PackedByteArray
	
	if push_constant is PackedByteArray:
		computed_pc = push_constant
	elif push_constant is Array:
		computed_pc = _array_to_bytes(push_constant)
	else:
		push_warning("Push constants must either be an Array or a PackedByteArray")

	if len(computed_pc) != 0:
		while computed_pc.size() % 16 != 0:
			computed_pc.append(0)

		_rd.compute_list_set_push_constant(
				compute_list,
				computed_pc,
				computed_pc.size()
			)

	_rd.compute_list_dispatch(compute_list, p.wgx, p.wgy, p.wgz)
	_rd.compute_list_end()
	
	if not _uses_global_rd:
		_rd.submit()

## Syncs the shader.
func sync() -> void:
	if _uses_global_rd:
		push_warning(
			"Sync should not be called when using the global RenderingDevice"
		)
		
		return
	
	_rd.sync()

## Performs cleanup, freeing data from the gpu. This should be called when
## you're finished with the [Compute] object, to avoid memory leaks.
func cleanup() -> void:
	for p in _pipelines:
		p.cleanup(_rd)
	
	for buffer in _buffers:
		_rd.free_rid(buffer)
	
	_rd.free()

## Creates another pipeline on this [Compute] object. Buffers are shared between
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

func _validate_binding(binding: int, type: _Buffer.Usage):
	assert(len(_buffers) > binding, "Binding %d does not exist!" % binding)

	assert(
			_buffers[binding].type == type,
			"Buffer %d is of type %s, not %s" % [
					binding,
					_Buffer.usage_string(_buffers[binding].type),
					_Buffer.usage_string(type)
				]
		)

static func _array_to_bytes(array: Array) -> PackedByteArray:
	var out := PackedByteArray()
		
	for elem in array:
		if elem is float:
			out.append_array(PackedFloat32Array([elem]).to_byte_array())
		
		elif elem is int:
			out.append_array(PackedInt32Array([elem]).to_byte_array())
		
		elif elem is Vector2:
			out.append_array(PackedFloat32Array([elem.x, elem.y]).to_byte_array())
		
		elif elem is Vector3:
			out.append_array(PackedFloat32Array([elem.x, elem.y, elem.z]).to_byte_array())
		
		elif elem is Vector4:
			out.append_array(PackedFloat32Array([elem.x, elem.y, elem.z, elem.w]).to_byte_array())
		
		elif elem is Color:
			out.append_array(PackedFloat32Array([elem.r, elem.g, elem.b, elem.a]).to_byte_array())
		
		elif elem is Vector2i:
			out.append_array(PackedInt32Array([elem.x, elem.y]).to_byte_array())
		
		elif elem is Vector3i:
			out.append_array(PackedInt32Array([elem.x, elem.y, elem.z]).to_byte_array())
		
		elif elem is Vector4i:
			out.append_array(PackedInt32Array([elem.x, elem.y, elem.z, elem.w]).to_byte_array())
		
		elif elem is Array:
			out.append_array(_array_to_bytes(elem))
		
		else:
			push_warning("Element of array in push constant is not of supported type: ", elem)
	
	return out

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

class _Buffer:
	enum Usage {DATA, IMAGE}

	var rid: RID
	var type: Usage

	static func usage_string(usage: Usage) -> String:
		match usage:
			Usage.DATA:
				return "data"
			Usage.IMAGE:
				return "image"
			_:
				return "unknown"
