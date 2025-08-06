@tool
class_name DepthFogEffectCompositorExample
extends CompositorEffect

var c := Compute.new(preload("depth_fog.glsl"), 1, 1, 1, true)

func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	
	if not render_scene_buffers:
		push_warning("Render scene buffers was null!")
		return
	
	var size := render_scene_buffers.get_internal_size()
	
	if size.x == 0 and size.y == 0:
		push_warning("Render scene buffers are 0x0")
		return
	
	var x_groups := (size.x - 1) / 8 + 1
	var y_groups := (size.y - 1) / 8 + 1
	
	for view in range(render_scene_buffers.get_view_count()):
		var color_image := render_scene_buffers.get_color_layer(view)
		var depth_image := render_scene_buffers.get_depth_layer(view)
		
		
		var color_uniform := RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(color_image)
		
		c.custom_uniform(color_uniform)
		
		var sampler_state := RDSamplerState.new()
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		var sampler := RenderingServer.get_rendering_device().sampler_create(sampler_state)
		
		var depth_uniform := RDUniform.new()
		depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth_uniform.binding = 1
		depth_uniform.add_id(sampler)
		depth_uniform.add_id(depth_image)
		
		c.custom_uniform(depth_uniform)
		
		c.update_wg_count(x_groups, y_groups, 1)
		
		c.submit()
