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

first_mouse := false

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

	vertices := []f32 {
	    -0.5, -0.5, -0.5,  0.0, 0.0,
	     0.5, -0.5, -0.5,  1.0, 0.0,
	     0.5,  0.5, -0.5,  1.0, 1.0,
	     0.5,  0.5, -0.5,  1.0, 1.0,
	    -0.5,  0.5, -0.5,  0.0, 1.0,
	    -0.5, -0.5, -0.5,  0.0, 0.0,

	    -0.5, -0.5,  0.5,  0.0, 0.0,
	     0.5, -0.5,  0.5,  1.0, 0.0,
	     0.5,  0.5,  0.5,  1.0, 1.0,
	     0.5,  0.5,  0.5,  1.0, 1.0,
	    -0.5,  0.5,  0.5,  0.0, 1.0,
	    -0.5, -0.5,  0.5,  0.0, 0.0,

	    -0.5,  0.5,  0.5,  1.0, 0.0,
	    -0.5,  0.5, -0.5,  1.0, 1.0,
	    -0.5, -0.5, -0.5,  0.0, 1.0,
	    -0.5, -0.5, -0.5,  0.0, 1.0,
	    -0.5, -0.5,  0.5,  0.0, 0.0,
	    -0.5,  0.5,  0.5,  1.0, 0.0,

	     0.5,  0.5,  0.5,  1.0, 0.0,
	     0.5,  0.5, -0.5,  1.0, 1.0,
	     0.5, -0.5, -0.5,  0.0, 1.0,
	     0.5, -0.5, -0.5,  0.0, 1.0,
	     0.5, -0.5,  0.5,  0.0, 0.0,
	     0.5,  0.5,  0.5,  1.0, 0.0,

	    -0.5, -0.5, -0.5,  0.0, 1.0,
	     0.5, -0.5, -0.5,  1.0, 1.0,
	     0.5, -0.5,  0.5,  1.0, 0.0,
	     0.5, -0.5,  0.5,  1.0, 0.0,
	    -0.5, -0.5,  0.5,  0.0, 0.0,
	    -0.5, -0.5, -0.5,  0.0, 1.0,

	    -0.5,  0.5, -0.5,  0.0, 1.0,
	     0.5,  0.5, -0.5,  1.0, 1.0,
	     0.5,  0.5,  0.5,  1.0, 0.0,
	     0.5,  0.5,  0.5,  1.0, 0.0,
	    -0.5,  0.5,  0.5,  0.0, 0.0,
	    -0.5,  0.5, -0.5,  0.0, 1.0
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


	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 5 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 5 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	texture1: u32
	gl.GenTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	{
		width, height, nr_channels: i32
		data := stbi.load("container.jpg", &width, &height, &nr_channels, 0)

		if data == nil {
			fmt.printfln("failed to load image")
			return
		}

		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}


	texture2: u32
	gl.GenTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)
	{
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

		width, height, nr_channels: i32
		stbi.set_flip_vertically_on_load(1)
		data := stbi.load("awesomeface.png", &width, &height, &nr_channels, 0)

		if data == nil {
			fmt.printfln("failed to load image")
			return
		}

		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

	gl.UseProgram(program)

	uniforms := gl.get_uniforms_from_program(program)
	gl.Uniform1i(uniforms["texture1"].location, 0)
	gl.Uniform1i(uniforms["texture2"].location, 1)

	cube_positions := []glm.vec3 {
		{0, 0, 0},
	    { 2.0,  5.0, -15.0},
	    {-1.5, -2.2, -2.5},
	    {-3.8, -2.0, -12.3},
	    { 2.4, -0.4, -3.5},
	    {-1.7,  3.0, -7.5},
	    { 1.3, -2.0, -2.5},
	    { 1.5,  2.0, -2.5},
	    { 1.5,  0.2, -1.5},
	    {-1.3,  1.0, -1.5},
	}

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
				fmt.printfln("cam y %v p %v", camera.yaw, camera.pitch)
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

		// Draw
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)


		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		gl.BindVertexArray(vao)

		projection := glm.mat4Perspective(glm.radians_f32(camera.zoom), 800.0 / 600.0, 0.1, 100.0)
		gl.UniformMatrix4fv(uniforms["projection"].location, 1, false, &projection[0, 0])

		radius: f32 = 10.0
		cam_x := math.sin(t) * radius
		cam_z := math.cos(t) * radius

		view := camera_get_view_matrix(camera)
		gl.UniformMatrix4fv(uniforms["view"].location, 1, false, &view[0, 0])

		for cube_position, i in cube_positions {
			model := glm.identity(glm.mat4)
			model = model * glm.mat4Translate(cube_position)
			angle := 20.0 * f32(i + 1)
			if i % 3 == 0 do angle *= math.sin(t)
			model = model * glm.mat4Rotate({1, 0.3, 0.5}, glm.radians_f32(angle))
			gl.UniformMatrix4fv(uniforms["model"].location, 1, false, &model[0, 0])				

			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}



		sdl.GL_SwapWindow(window)	
	}
}
