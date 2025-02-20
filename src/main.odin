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

	gl_context := sdl.GL_CreateContext(window)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, sdl.gl_set_proc_address)

	gl.Viewport(0, 0, SCREEN_SIZE.x, SCREEN_SIZE.y)

	program, program_ok := gl.load_shaders_file("shader.vert", "shader.frag")
	if !program_ok {
		fmt.eprintfln("Failed to create GLSL Program")
		return
	}

	vertices := []f32 {
		// positions     // colors        //texture coords
		0.5, 0.5, 0.0,   1.0, 0.0, 0.0,   1, 1, // top right
		0.5, -0.5, 0.0,  0.0, 1.0, 0.0,   1, 0, // bottom right
		-0.5, -0.5, 0.0, 0.0, 0.0, 1.0,   0, 0, // bottom left
		-0.5, 0.5, 0.0,  1.0, 1.0, 0.0,   0, 1, // top left
	}

	indices := []u32 {
		0, 1, 3,
		1, 2, 3
	}


	vbo, ebo, vao: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices),
		raw_data(vertices),
		gl.STATIC_DRAW
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices), raw_data(indices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(f32), uintptr(6 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

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

	start_tick := time.tick_now()
	loop: for {
		duration := time.tick_since(start_tick)
		t := f32(time.duration_seconds(duration))
		for e: sdl.Event; sdl.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				break loop
			case .WINDOW_RESIZED:
				we := e.window
				gl.Viewport(0, 0, we.data1, we.data2)
			}
		}

		// Draw
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)


		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		gl.BindVertexArray(vao)
		{
			trans := glm.identity(glm.mat4)
			trans = trans * glm.mat4Translate({0.5, -0.5, 0})
			trans = trans * glm.mat4Rotate({0, 0, 1}, t)
			gl.UniformMatrix4fv(uniforms["transform"].location, 1, false, &trans[0, 0])

			gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, rawptr(uintptr(0)))
		}

		{
			trans := glm.identity(glm.mat4)
			s := math.sin(t)
			trans = trans * glm.mat4Scale({s, s, 0})
			trans = trans * glm.mat4Translate({-0.5, 0.5, 0})


			gl.UniformMatrix4fv(uniforms["transform"].location, 1, false, &trans[0, 0])
			gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, rawptr(uintptr(0)))
		}


		sdl.GL_SwapWindow(window)	
	}
}
