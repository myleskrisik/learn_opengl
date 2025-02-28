package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:time"
import "core:slice"
import sa "core:container/small_array"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"
import glm "core:math/linalg/glsl"
import gltf "vendor:cgltf"

SCREEN_SIZE :: [2]i32{800, 600}

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

Input :: struct {
	ended_down: bool,
	half_transitions: u32,
}

Actions :: enum {
	Move_Forward,
	Move_Backward,
	Move_Left,
	Move_Right,
}

YAW         :: -90.0
PITCH       ::  0.0
SPEED       ::  2.5
SENSITIVITY ::  0.3
ZOOM        ::  45.0

Camera :: struct {
	position: glm.vec3,
	front: glm.vec3,
	up: glm.vec3,
	right: glm.vec3,
	world_up: glm.vec3,
	yaw: f32,
	pitch: f32,
	movement_speed: f32,
	mouse_sensitivity: f32,
	zoom: f32
}

Vertex :: struct {
	position: glm.vec3,
	normal: glm.vec3,
	tex_coord: glm.vec2,
}

Texture :: struct {
	id: u32,
	type: string,
}

Mesh :: struct {
	texture: Texture,
	num_indices: i32,
	vao, vbo, ebo: u32,
}

mesh_init :: proc(texture: Texture, num_indices: i32, vao, vbo, ebo: u32) -> Mesh {
	return {
		texture,
		num_indices,
		vao,
		vbo,
		ebo,
	}
}

mesh_draw :: proc(mesh: Mesh, shader_program: u32, uniforms: gl.Uniforms) {
	t := mesh.texture
	name := t.type
	number: int

	gl.ActiveTexture(u32(gl.TEXTURE0))
	gl.BindTexture(gl.TEXTURE_2D, t.id)

	gl.UseProgram(shader_program)
	gl.Uniform1i(uniforms["diffuse"].location, 0)

	// draw mesh
	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_INT, rawptr(uintptr(0)))
	gl.BindVertexArray(0)
}

Model :: struct {
	meshes: []Mesh,
}

model_load :: proc(path: cstring) -> (Model, bool) {
	options: gltf.options
	data, parse_res := gltf.parse_file(options, path)
	if parse_res != .success do return Model{}, false

	load_buf_res := gltf.load_buffers(options, data, path)
	if load_buf_res != .success do return Model{}, false

	assert(len(data.nodes) == 1)

	meshes := make([]Mesh, len(data.meshes))
	for mesh, i in data.meshes {
		for primitive in mesh.primitives {
			if primitive.type != .triangles do continue
			
			material := primitive.material
			assert(bool(material.has_pbr_metallic_roughness), "Primitive material did not have pbr metallic roughness")
			texture := material.pbr_metallic_roughness.base_color_texture.texture
			sampler := texture.sampler
			image := texture.image_

			mesh_texture: Texture
			mesh_texture.type = "diffuse"
			gl.GenTextures(1, &mesh_texture.id)

			width, height, nr_channels: i32
			img_data := stbi.load(image.uri, &width, &height, &nr_channels, 0)

			if img_data == nil {
				fmt.printfln("failed to load image with name: %v", image.uri)
				continue
			}

			format: u32
			switch nr_channels {
				case 1:
					format = gl.RED
				case 3:
					format = gl.RGB
				case 4:
					format = gl.RGBA
			}

			gl.ActiveTexture(gl.TEXTURE0)
			gl.BindTexture(gl.TEXTURE_2D, mesh_texture.id)
			gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, format, gl.UNSIGNED_BYTE, img_data)
			gl.GenerateMipmap(mesh_texture.id)

			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, sampler.wrap_s)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, sampler.wrap_t)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, sampler.min_filter)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, sampler.mag_filter)
			fmt.println(sampler.min_filter)
			fmt.println(sampler.mag_filter)

			stbi.image_free(img_data)

			// Parse Vertex Data
			positions, normals, tex_coords: ^gltf.accessor
			positions_ok, normals_ok, tex_coords_ok: bool
			for attribute in primitive.attributes {
				accessor := attribute.data
				#partial switch attribute.type {
				case .position:
					positions = accessor
					positions_ok = true
					assert(accessor.type == .vec3, "Position attribute isn't vec3")
				case .normal:
					normals = accessor
					normals_ok = true
					assert(accessor.type == .vec3, "Normal attribute isn't vec3")
				case .texcoord:
					tex_coords = accessor
					tex_coords_ok = true
					assert(accessor.type == .vec2, "Tex Coord attribute isn't vec2")
				}
			}
			assert(positions_ok, "Position attribute was not found")
			assert(normals_ok, "Normal attribute was not found")
			assert(tex_coords_ok, "Tex Coords_ok attribute was not found")

			num_vertices := positions.count

			assert(num_vertices == normals.count, "Number of Normals is not equal to number of vertices")
			assert(num_vertices == tex_coords.count, "Number of Tex coords is not equal to number of vertices")

			vao, vbo, ebo: u32
			gl.GenVertexArrays(1, &vao)
			gl.GenBuffers(1, &vbo)
			gl.GenBuffers(1, &ebo)
			meshes[i] = mesh_init(mesh_texture, i32(primitive.indices.count), vao, vbo, ebo)

			gl.BindVertexArray(vao)

			// Load Vertex Data
			gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

			// loop over all buffers and assemble vertices
			vertices := make([]Vertex, num_vertices)
			for j in 0 ..< num_vertices {
				v: Vertex
				raw_pos := raw_data(v.position[:])
				if !gltf.accessor_read_float(positions, j, raw_pos, 3) {
					panic("failed to parse float for position")
				}
				raw_normal := raw_data(v.normal[:])
				if !gltf.accessor_read_float(normals, j, raw_normal, 3) {
					panic("failed to parse float for normal")
				}
				raw_tex_coord := raw_data(v.tex_coord[:])
				if !gltf.accessor_read_float(tex_coords, j, raw_tex_coord, 2) {
					panic("failed to parse float for tex coord")
				}
				vertices[j] = v
			}
			gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)
			delete(vertices)

			// Load indices
			indices := make([]u32, primitive.indices.count)
			for j in 0 ..< primitive.indices.count {
				index: u32
				if !gltf.accessor_read_uint(primitive.indices, j, &index, 1) {
					panic("failed to parse u32 for indices")
				}
				indices[j] = index
			}
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
			gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices), raw_data(indices), gl.STATIC_DRAW)
			delete(indices)

			// Set Vertex Attributes Pointers
			gl.EnableVertexAttribArray(0)
			gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), uintptr(0))

			gl.EnableVertexAttribArray(1)
			gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

			gl.EnableVertexAttribArray(2)
			gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex_coord))

			gl.BindVertexArray(0)
		}
	}
	return model_init(meshes), true
}

model_draw :: proc(model: Model, shader_program: u32, uniforms: gl.Uniforms) {
	for mesh in model.meshes do mesh_draw(mesh, shader_program, uniforms)
}

model_init :: proc(meshes: []Mesh) -> Model {
	return {
		meshes
	}
}

camera_new :: proc(
	position: glm.vec3 = {0, 0, 0},
	up: glm.vec3 = {0, 1, 0},
	yaw: f32 = YAW,
	pitch: f32 = PITCH
) -> (camera: Camera) {
	camera.position = position
	camera.world_up = up
	camera.front = {0, 0, -1}
	camera.yaw = yaw
	camera.pitch = pitch
	camera.movement_speed = SPEED
	camera.mouse_sensitivity = SENSITIVITY
	camera.zoom = ZOOM
	camera_update_vectors(&camera)
	return
}

camera_update_vectors :: proc(camera: ^Camera) {
	front: glm.vec3
	front.x = math.cos(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch))
	front.y = math.sin(glm.radians(camera.pitch))
	front.z = math.sin(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch))
	camera.front = glm.normalize(front)

	camera.right = glm.normalize(glm.cross(camera.front, camera.world_up))
	camera.up = glm.normalize(glm.cross(camera.right, camera.front))
}

camera_get_view_matrix :: proc(camera: Camera) -> matrix[4,4]f32 {
	return glm.mat4LookAt(camera.position, camera.position + camera.front, camera.up)
}

input_state: [Actions]Input

camera := camera_new({0, 0, 3})

main :: proc() {
	if !sdl.Init({.VIDEO}) {
		fmt.eprintfln("SDL could not initialize! SDL_Error: %v\n", sdl.GetError())
		return
	}

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLProfileFlag.CORE))

	window: ^sdl.Window
	if window = sdl.CreateWindow(
		"Basic SDL3",
		SCREEN_SIZE.x,
		SCREEN_SIZE.y,
		{.OPENGL, .RESIZABLE}
	); window == nil {
		fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.GetError())
		return
	}

	if sdl.SetWindowRelativeMouseMode(window, true) {
		fmt.eprintln("failed to grab mouse input")
	}

	gl_context := sdl.GL_CreateContext(window)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, sdl.gl_set_proc_address)
	gl.Enable(gl.DEPTH_TEST)
	gl.Viewport(0, 0, SCREEN_SIZE.x, SCREEN_SIZE.y)

	program, program_ok := gl.load_shaders_file("shader.vert", "shader.frag")
	if !program_ok {
		fmt.eprintfln("Failed to create GLSL Program")
		return
	}
	uniforms := gl.get_uniforms_from_program(program)

	light_program, light_program_ok := gl.load_shaders_file("shader.vert", "light_shader.frag")
	if !light_program_ok {
		fmt.eprintfln("Failed to create light GLSL Progra")
		return
	}
	light_uniforms := gl.get_uniforms_from_program(light_program)

	vertices := []f32 {
	    // positions
	    -0.5, -0.5, -0.5,
	     0.5, -0.5, -0.5,
	     0.5,  0.5, -0.5,
	     0.5,  0.5, -0.5,
	    -0.5,  0.5, -0.5,
	    -0.5, -0.5, -0.5,

	    -0.5, -0.5,  0.5,
	     0.5, -0.5,  0.5,
	     0.5,  0.5,  0.5,
	     0.5,  0.5,  0.5,
	    -0.5,  0.5,  0.5,
	    -0.5, -0.5,  0.5,

	    -0.5,  0.5,  0.5,
	    -0.5,  0.5, -0.5,
	    -0.5, -0.5, -0.5,
	    -0.5, -0.5, -0.5,
	    -0.5, -0.5,  0.5,
	    -0.5,  0.5,  0.5,

	     0.5,  0.5,  0.5,
	     0.5,  0.5, -0.5,
	     0.5, -0.5, -0.5,
	     0.5, -0.5, -0.5,
	     0.5, -0.5,  0.5,
	     0.5,  0.5,  0.5,

	    -0.5, -0.5, -0.5,
	     0.5, -0.5, -0.5,
	     0.5, -0.5,  0.5,
	     0.5, -0.5,  0.5,
	    -0.5, -0.5,  0.5,
	    -0.5, -0.5, -0.5,

	    -0.5,  0.5, -0.5,
	     0.5,  0.5, -0.5,
	     0.5,  0.5,  0.5,
	     0.5,  0.5,  0.5,
	    -0.5,  0.5,  0.5,
	    -0.5,  0.5, -0.5,
	}

	light_vao, vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &light_vao)
	gl.BindVertexArray(light_vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices),
		raw_data(vertices),
		gl.STATIC_DRAW
	)


	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	light_pos := glm.vec3 {1.2, 1, 2}

	start_tick := time.tick_now()
	delta_time: f64 = 0
	last_frame: f64 = 0

	point_light_positions := []glm.vec3 {
		{ 0.7,  0.2,  2.0},
		{ 2.3, -3.3, -4.0},
		{-4.0,  2.0, -12.0},
		{ 0.0,  0.0, -3.}
	}

	gl.UseProgram(program)

	light_color := glm.vec3 {1, 1, 1}
	ambient_color := light_color * glm.vec3 {0.1, 0.1, 0.1}
	diffuse_color := light_color * glm.vec3 {0.5, 0.5, 0.5}

	for pos, i in point_light_positions {
		gl.Uniform3f(uniforms[fmt.tprintf("pointLights[%v].position", i)].location, pos.x, pos.y, pos.z)
		gl.Uniform1f(uniforms[fmt.tprintf("pointLights[%v].constant", i)].location, 1)
		gl.Uniform1f(uniforms[fmt.tprintf("pointLights[%v].linear", i)].location, 0.09)
		gl.Uniform1f(uniforms[fmt.tprintf("pointLights[%v].quadratic", i)].location, 0.032)
		gl.Uniform3f(uniforms[fmt.tprintf("pointLights[%v].ambient", i)].location, ambient_color.x, ambient_color.y, ambient_color.z)
		gl.Uniform3f(uniforms[fmt.tprintf("pointLights[%v].diffuse", i)].location, diffuse_color.x, diffuse_color.y, diffuse_color.z)
		gl.Uniform3f(uniforms[fmt.tprintf("pointLights[%v].specular", i)].location, 1, 1, 1)
	}
	free_all(context.temp_allocator)

	gl.Uniform3f(uniforms["DirLight.direction"].location, -0.2, -1, -0.3)
	gl.Uniform3f(uniforms["DirLight.ambient"].location, ambient_color.x, ambient_color.y, ambient_color.z)
	gl.Uniform3f(uniforms["DirLight.diffuse"].location, diffuse_color.x, diffuse_color.y, diffuse_color.z)
	gl.Uniform3f(uniforms["DirLight.specular"].location, 1, 1, 1)

	cart_model, cart_model_ok := model_load("cart.gltf")
	if !cart_model_ok {
		fmt.printfln("failed to load cart model")
		return
	}

	loop: for {
		duration := time.tick_since(start_tick)
		current_frame := time.duration_seconds(duration)
		delta_time = current_frame - last_frame
		last_frame = current_frame
		t := f32(time.duration_seconds(duration))
		for e: sdl.Event; sdl.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				break loop
			case .WINDOW_RESIZED:
				we := e.window
				gl.Viewport(0, 0, we.data1, we.data2)
			case .KEY_DOWN, .KEY_UP:
				k := e.key
				is_down := e.type == .KEY_DOWN

				#partial switch k.scancode {
				case .W:
					input_state[.Move_Forward].ended_down = is_down
					input_state[.Move_Forward].half_transitions += 1

				case .S:
					input_state[.Move_Backward].ended_down = is_down
					input_state[.Move_Backward].half_transitions += 1

				case .A:
					input_state[.Move_Left].ended_down = is_down					
					input_state[.Move_Left].half_transitions += 1	
				case .D:
					input_state[.Move_Right].ended_down = is_down
					input_state[.Move_Right].half_transitions += 1
				case .ESCAPE:
					break loop
				}
			case .MOUSE_MOTION:
				m := e.motion

				x_offset := m.xrel * camera.mouse_sensitivity
				y_offset := -m.yrel * camera.mouse_sensitivity

				camera.yaw += x_offset
				camera.pitch += y_offset

				camera.pitch = clamp(camera.pitch, -89, 89)
				camera_update_vectors(&camera)
			case .MOUSE_WHEEL:
				w := e.wheel
				camera.zoom -= w.y
				camera.zoom = clamp(camera.zoom, 1, 60)
			}
		}
		if input_state[.Move_Forward].ended_down {
			camera.position += camera.movement_speed * camera.front * f32(delta_time)
		}
		if input_state[.Move_Backward].ended_down {
			camera.position -= camera.movement_speed * camera.front * f32(delta_time)
		}
		if input_state[.Move_Left].ended_down {
			camera.position -= glm.normalize(
				glm.cross(camera.front, camera.up)
			) * camera.movement_speed * f32(delta_time)
		}
		if input_state[.Move_Right].ended_down {
			camera.position += glm.normalize(
				glm.cross(camera.front, camera.up)
			) * camera.movement_speed * f32(delta_time)
		}
		camera_update_vectors(&camera)

		gl.UseProgram(program)

		// Draw
		gl.ClearColor(0.8, 0.8, 0.8, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		projection := glm.mat4Perspective(glm.radians_f32(camera.zoom), 1600.0 / 900.0, 0.1, 100.0)

		view := camera_get_view_matrix(camera)
		{
			gl.UseProgram(program)
			gl.Uniform3f(uniforms["viewPos"].location, camera.position.x, camera.position.y, camera.position.z)
			gl.UniformMatrix4fv(uniforms["projection"].location, 1, false, &projection[0, 0])
			gl.UniformMatrix4fv(uniforms["view"].location, 1, false, &view[0, 0])

			model := glm.identity(glm.mat4)
			model = model * glm.mat4Scale({1, 1, 1})
			model = model * glm.mat4Translate({0, -1.5, 0})
			gl.UniformMatrix4fv(uniforms["model"].location, 1, false, &model[0, 0])
			model_draw(cart_model, program, uniforms)
		}
		{
			gl.UseProgram(light_program)
			gl.Uniform3f(light_uniforms["lightColor"].location, light_color.x, light_color.y, light_color.z)

			gl.UniformMatrix4fv(light_uniforms["projection"].location, 1, false, &projection[0, 0])
			gl.UniformMatrix4fv(light_uniforms["view"].location, 1, false, &view[0, 0])

			for pos in point_light_positions {
				model := glm.identity(glm.mat4)
				model = model * glm.mat4Translate(pos)
				model = model * glm.mat4Scale({0.2, 0.2, 0.2})
				gl.UniformMatrix4fv(light_uniforms["model"].location, 1, false, &model[0, 0])

				gl.BindVertexArray(light_vao)
				gl.DrawArrays(gl.TRIANGLES, 0, 36)	
			}
			
		}
		sdl.GL_SwapWindow(window)
	}
}
