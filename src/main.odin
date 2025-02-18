package main

import "core:fmt"
import "core:strings"
import "core:math"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"

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

		// Compile vertex shader
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(vertex_shader)
	// Check if vertex compilation succeeded
	{
		success: i32
		gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
		if success == 0 {
			info_log: [512]u8
			len: i32
			gl.GetShaderInfoLog(vertex_shader, 512, &len, raw_data(&info_log))
		    err := strings.string_from_ptr(raw_data(&info_log), int(len))

		    fmt.printfln("Vertex Shader Compilation Error:\n%v", err)
		    return
		}
	}


	// Compile fragment shader
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(fragment_shader)
	// Check if fragment compilation succeeded
	{
		success: i32
		gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
		if success == 0 {
			info_log: [512]u8
			len: i32
			gl.GetShaderInfoLog(fragment_shader, 512, &len, raw_data(&info_log))
		    err := strings.string_from_ptr(raw_data(&info_log), int(len))

		    fmt.printfln("Fragment Shader Compilation Error:\n%v", err)
		    return
		}
	}

	// Compile fragment shader
	fragment_shader_0 := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader_0, 1, &fragment_shader_0_source, nil)
	gl.CompileShader(fragment_shader_0)
	// Check if fragment compilation succeeded
	{
		success: i32
		gl.GetShaderiv(fragment_shader_0, gl.COMPILE_STATUS, &success)
		if success == 0 {
			info_log: [512]u8
			len: i32
			gl.GetShaderInfoLog(fragment_shader_0, 512, &len, raw_data(&info_log))
		    err := strings.string_from_ptr(raw_data(&info_log), int(len))

		    fmt.printfln("Fragment Shader Compilation Error:\n%v", err)
		    return
		}
	}	

	// Create shader program
	shader_program := gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)
	// Check if Program linking succeeded
	{
		success: i32
		gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)
		if success == 0 {
			info_log: [512]u8
			len: i32
			gl.GetProgramInfoLog(shader_program, 512, &len, raw_data(&info_log))
			err := strings.string_from_ptr(raw_data(&info_log), int(len))

			fmt.printfln("Shader program linking failed:\n%v", err)
			return
		}
	}

	// Create shader program
	shader_program_0 := gl.CreateProgram()
	gl.AttachShader(shader_program_0, vertex_shader)
	gl.AttachShader(shader_program_0, fragment_shader_0)
	gl.LinkProgram(shader_program_0)
	// Check if Program linking succeeded
	{
		success: i32
		gl.GetProgramiv(shader_program_0, gl.LINK_STATUS, &success)
		if success == 0 {
			info_log: [512]u8
			len: i32
			gl.GetProgramInfoLog(shader_program_0, 512, &len, raw_data(&info_log))
			err := strings.string_from_ptr(raw_data(&info_log), int(len))

			fmt.printfln("Shader program linking failed:\n%v", err)
			return
		}
	}
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)
	gl.DeleteShader(fragment_shader_0)

	vao: u32
	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)

	vertices := []f32 {
		-0.5, -0.5, 0.0, 1.0, 0.0, 0.0,
		0.5, -0.5, 0.0, 0.0, 1.0, 0.0,
		0.0, 0.5, 0.0, 0.0, 0.0, 1.0
	}

	square_vertices := []f32 {
		0.5, 0.5, 0.0, // top right
		0.5, -0.5, 0.0, // bottom right
		-0.5, -0.5, 0.0, // bottom left
		-0.5, 0.5, 0.0 // top left
	}

	two_triangles_vertices := []f32 {
		-0.5, 0, 0,
		-0.25, 0, 0,
		-0.375, 0.25, 0,
		0.25, 0, 0,
		0.5, 0, 0,
		0.375, 0.25, 0
	}

	indices := []u32 {
		0, 1, 3,
		1, 2, 3
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices),
		raw_data(vertices),
		gl.STATIC_DRAW
	)

	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(indices), raw_data(indices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 6 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 6 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)


	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	// Setup triangle 0
	vao_0: u32
	gl.GenVertexArrays(1, &vao_0)
	gl.BindVertexArray(vao_0)

	vbo_0: u32
	gl.GenBuffers(1, &vbo_0)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo_0)
	triangle_0_vertices := []f32 {
		-0.5, 0, 0,
		-0.25, 0, 0,
		-0.375, 0.25, 0,	
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(triangle_0_vertices) * size_of(triangle_0_vertices),
		raw_data(triangle_0_vertices),
		gl.STATIC_DRAW
	)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	// Setup triangle 1
	vao_1: u32
	gl.GenVertexArrays(1, &vao_1)
	gl.BindVertexArray(vao_1)

	vbo_1: u32
	gl.GenBuffers(1, &vbo_1)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo_1)
	triangle_1_vertices := []f32 {
		0.25, 0, 0,
		0.5, 0, 0,
		0.375, 0.25, 0
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(triangle_1_vertices) * size_of(triangle_1_vertices),
		raw_data(triangle_1_vertices),
		gl.STATIC_DRAW
	)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)	


	loop: for {
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

		vertex_x_offset_location := gl.GetUniformLocation(shader_program, "xOffset")
		gl.UseProgram(shader_program)
		gl.Uniform1f(vertex_x_offset_location, 0.6)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		// gl.UseProgram(shader_program)
		// gl.BindVertexArray(vao_0)
		// gl.DrawArrays(gl.TRIANGLES, 0, 3)


		// gl.UseProgram(shader_program_0)
		// gl.BindVertexArray(vao_1)
		// gl.DrawArrays(gl.TRIANGLES, 0, 3)

		// gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, rawptr(0))

		sdl.GL_SwapWindow(window)	
	}
}

vertex_shader_source: cstring = `#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;
out vec4 vertexPosition;

uniform float xOffset;

void main()
{
	gl_Position = vec4(aPos.x + xOffset, aPos.yz, 1.0);
	vertexPosition = gl_Position;
	ourColor = aColor;
}
`

fragment_shader_source: cstring = `#version 330 core
out vec4 FragColor;
in vec3 ourColor;
in vec4 vertexPosition;

void main()
{
	FragColor = vertexPosition;
}
`

fragment_shader_0_source: cstring = `#version 330 core
out vec4 FragColor;

void main()
{
	FragColor = vec4(1.0f, 1.0f, 0.01f, 1.0f);
}
`