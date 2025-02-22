package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:time"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"
import glm "core:math/linalg/glsl"

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
	    // positions       // normals        // texture coords
	    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
	     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
	     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
	     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
	    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
	    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,

	    -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,
	     0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 0.0,
	     0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
	     0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   1.0, 1.0,
	    -0.5,  0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 1.0,
	    -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,   0.0, 0.0,

	    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
	    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
	    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
	    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
	    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,
	    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,

	     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
	     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
	     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
	     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
	     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
	     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

	    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
	     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
	     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
	     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
	    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,
	    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,

	    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
	     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
	     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
	     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
	    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
	    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0
	}


	vbo, vao: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices),
		raw_data(vertices),
		gl.STATIC_DRAW
	)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(f32), uintptr(6 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

	light_vao: u32
	gl.GenVertexArrays(1, &light_vao)
	gl.BindVertexArray(light_vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	diffuse_map: u32
	gl.GenTextures(1, &diffuse_map)
	{
		width, height, nr_channels: i32
		data := stbi.load("container2.png", &width, &height, &nr_channels, 0)

		if data == nil {
			fmt.printfln("failed to load image")
			return
		}

		gl.BindTexture(gl.TEXTURE_2D, diffuse_map)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	}

	specular_map: u32
	gl.GenTextures(1, &specular_map)
	{
		width, height, nr_channels: i32
		data := stbi.load("container2_specular.png", &width, &height, &nr_channels, 0)

		if data == nil {
			fmt.printfln("failed to load image")
			return
		}

		gl.BindTexture(gl.TEXTURE_2D, specular_map)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	}


	gl.UseProgram(program)
	gl.Uniform1i(uniforms["material.diffuse"].location, 0)
	gl.Uniform1i(uniforms["material.specular"].location, 1)

	light_pos := glm.vec3 {1.2, 1, 2}

	start_tick := time.tick_now()
	delta_time: f64 = 0
	last_frame: f64 = 0
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

		// Material
		gl.Uniform1f(uniforms["material.shininess"].location, 32)

		// Draw
		gl.ClearColor(0.1, 0.1, 0.1, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		projection := glm.mat4Perspective(glm.radians_f32(camera.zoom), 1600.0 / 900.0, 0.1, 100.0)
		
		radius: f32 = 1.5
		light_pos = {math.sin(t / 4) * radius, 1.3, math.cos(t / 4) * radius}

		view := camera_get_view_matrix(camera)

		light_color: glm.vec3
		light_color.x = math.sin(t * 0.6)
		light_color.y = math.sin(t)
		light_color.z = math.sin(t * 0.2)
		// light_color = {1, 1, 1}

		ambient_color := light_color * glm.vec3 {0.2, 0.2, 0.2}
		diffuse_color := light_color * glm.vec3 {0.5, 0.5, 0.5}

		{
			gl.UseProgram(program)
			gl.Uniform3f(uniforms["viewPos"].location, camera.position.x, camera.position.y, camera.position.z)

			gl.Uniform3f(uniforms["light.position"].location, light_pos.x, light_pos.y, light_pos.z)
			gl.Uniform3f(uniforms["light.ambient"].location, ambient_color.x, ambient_color.y, ambient_color.z)
			gl.Uniform3f(uniforms["light.diffuse"].location, diffuse_color.x, diffuse_color.y, diffuse_color.z)
			gl.Uniform3f(uniforms["light.specular"].location, 1, 1, 1)

			gl.UniformMatrix4fv(uniforms["projection"].location, 1, false, &projection[0, 0])
			gl.UniformMatrix4fv(uniforms["view"].location, 1, false, &view[0, 0])

			model := glm.identity(glm.mat4)
			gl.UniformMatrix4fv(uniforms["model"].location, 1, false, &model[0, 0])

			gl.ActiveTexture(gl.TEXTURE0)
			gl.BindTexture(gl.TEXTURE_2D, diffuse_map)

			gl.ActiveTexture(gl.TEXTURE1)
			gl.BindTexture(gl.TEXTURE_2D, specular_map)

			gl.BindVertexArray(vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)	
		}
		
		{
			gl.UseProgram(light_program)
			gl.Uniform3f(light_uniforms["lightColor"].location, light_color.x, light_color.y, light_color.z)

			gl.UniformMatrix4fv(light_uniforms["projection"].location, 1, false, &projection[0, 0])
			gl.UniformMatrix4fv(light_uniforms["view"].location, 1, false, &view[0, 0])

			model := glm.identity(glm.mat4)
			model = model * glm.mat4Translate(light_pos)
			model = model * glm.mat4Scale({0.2, 0.2, 0.2})
			gl.UniformMatrix4fv(light_uniforms["model"].location, 1, false, &model[0, 0])

			gl.BindVertexArray(light_vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}



		sdl.GL_SwapWindow(window)
	}
}
