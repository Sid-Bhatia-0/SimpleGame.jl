import ModernGL as MGL
import DataStructures as DS
import GLFW
import SimpleDraw as SD
import SimpleIMGUI as SI
import FileIO
import ImageIO
import ColorTypes as CT
import FixedPointNumbers as FPN

include("opengl_utils.jl")
include("colors.jl")
include("textures.jl")

function SD.put_pixel_inbounds!(image, i, j, color::BinaryTransparentColor)
    if !iszero(CT.alpha(color.color))
        @inbounds image[i, j] = color.color
    end

    return nothing
end

function update_button(button, action)
    if action == GLFW.PRESS
        return SI.press(button)
    elseif action == GLFW.RELEASE
        return SI.release(button)
    else
        return button
    end
end

function start()
    primary_monitor = GLFW.GetPrimaryMonitor()
    video_mode = GLFW.GetVideoMode(primary_monitor)
    image_height = Int(video_mode.height)
    image_width = Int(video_mode.width)
    window_name = "Example"

    image = zeros(CT.RGBA{FPN.N0f8}, image_height, image_width)

    setup_window_hints()
    window = GLFW.CreateWindow(image_width, image_height, window_name, primary_monitor)
    GLFW.MakeContextCurrent(window)

    user_input_state = SI.UserInputState(
        SI.Cursor(SD.Point(1, 1)),
        fill(SI.InputButton(false, 0), 512),
        fill(SI.InputButton(false, 0), 8),
        Char[],
    )

    function cursor_position_callback(window, x, y)::Cvoid
        user_input_state.cursor.position = SD.Point(round(Int, y, RoundDown) + 1, round(Int, x, RoundDown) + 1)

        return nothing
    end

    function key_callback(window, key, scancode, action, mods)::Cvoid
        if key == GLFW.KEY_UNKNOWN
            @error "Unknown key pressed"
        else
            if key == GLFW.KEY_BACKSPACE && (action == GLFW.PRESS || action == GLFW.REPEAT)
                push!(user_input_state.characters, '\b')
            end

            user_input_state.keyboard_buttons[Int(key) + 1] = update_button(user_input_state.keyboard_buttons[Int(key) + 1], action)
        end

        return nothing
    end

    function mouse_button_callback(window, button, action, mods)::Cvoid
        user_input_state.mouse_buttons[Int(button) + 1] = update_button(user_input_state.mouse_buttons[Int(button) + 1], action)

        return nothing
    end

    function character_callback(window, unicode_codepoint)::Cvoid
        push!(user_input_state.characters, Char(unicode_codepoint))

        return nothing
    end

    GLFW.SetCursorPosCallback(window, cursor_position_callback)
    GLFW.SetKeyCallback(window, key_callback)
    GLFW.SetMouseButtonCallback(window, mouse_button_callback)
    GLFW.SetCharCallback(window, character_callback)

    MGL.glViewport(0, 0, image_width, image_height)

    vertex_shader = setup_vertex_shader()
    fragment_shader = setup_fragment_shader()
    shader_program = setup_shader_program(vertex_shader, fragment_shader)

    VAO_ref, VBO_ref, EBO_ref = setup_vao_vbo_ebo()

    texture_ref = setup_texture(image)

    MGL.glUseProgram(shader_program)
    MGL.glBindVertexArray(VAO_ref[])

    clear_display()

    user_interaction_state = SI.UserInteractionState(SI.NULL_WIDGET, SI.NULL_WIDGET, SI.NULL_WIDGET)

    layout = SI.BoxLayout(SD.Rectangle(SD.Point(1, 1), image_height, image_width))

    font = SD.TERMINUS_BOLD_24_12
    font_height = SD.get_height(font)
    font_width = SD.get_width(font)

    show_debug_text = true
    debug_text_list = String[]

    # assets
    color_type = BinaryTransparentColor{CT.RGBA{FPN.N0f8}}
    texture_atlas = TextureAtlas(color_type[])
    background_ti = load_texture(texture_atlas, "assets/background.png")
    burning_loop_animation_ti = load_texture(texture_atlas, "assets/burning_loop_1.png", 8)

    ui_context = SI.UIContext(user_interaction_state, user_input_state, layout, COLORS, Any[])

    i = 0

    sliding_window_size = 30

    max_frames_per_second = 60
    min_seconds_per_frame = 1 / max_frames_per_second

    frame_time_stamp_buffer = DS.CircularBuffer{typeof(time_ns())}(sliding_window_size)
    push!(frame_time_stamp_buffer, time_ns())

    frame_compute_time_buffer = DS.CircularBuffer{typeof(time_ns())}(sliding_window_size)
    push!(frame_compute_time_buffer, zero(UInt))

    texture_upload_time_buffer = DS.CircularBuffer{typeof(time_ns())}(sliding_window_size)
    push!(texture_upload_time_buffer, zero(UInt))

    while !GLFW.WindowShouldClose(window)
        if SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_ESCAPE) + 1])
            GLFW.SetWindowShouldClose(window, true)
            break
        end

        if SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_D) + 1])
            show_debug_text = !show_debug_text
        end

        layout.reference_bounding_box = SD.Rectangle(SD.Point(1, 1), image_height, image_width)
        empty!(debug_text_list)

        compute_time_start = time_ns()

        text = "Press the escape key to quit"
        SI.do_widget!(
            SI.TEXT,
            ui_context,
            SI.WidgetID(@__FILE__, @__LINE__, 1),
            text;
            alignment = SI.UP1_LEFT1,
        )

        push!(debug_text_list, "previous frame number: $(i)")
        push!(debug_text_list, "average total time spent per frame (averaged over previous $(length(frame_time_stamp_buffer)) frames): $(round((last(frame_time_stamp_buffer) - first(frame_time_stamp_buffer)) / (1e6 * length(frame_time_stamp_buffer)), digits = 2)) ms")
        push!(debug_text_list, "average compute time spent per frame (averaged over previous $(length(frame_compute_time_buffer)) frames): $(round(sum(frame_compute_time_buffer) / (1e6 * length(frame_compute_time_buffer)), digits = 2)) ms")
        push!(debug_text_list, "average texture upload time spent per frame (averaged over previous $(length(texture_upload_time_buffer)) frames): $(round(sum(texture_upload_time_buffer) / (1e6 * length(texture_upload_time_buffer)), digits = 3)) ms")

        if show_debug_text
            for (j, text) in enumerate(debug_text_list)
                SI.do_widget!(
                    SI.TEXT,
                    ui_context,
                    SI.WidgetID(@__FILE__, @__LINE__, j),
                    text;
                )
            end
        end

        SD.draw!(image, SD.Image(SD.Point(1, 1), get_texture(texture_atlas, background_ti)))

        animation_frame = mod1(i, 8)
        SD.draw!(image, SD.Image(SD.Point(540, 960), get_texture(texture_atlas, burning_loop_animation_ti, animation_frame)))

        for drawable in ui_context.draw_list
            SD.draw!(image, drawable)
        end
        empty!(ui_context.draw_list)

        compute_time_end = time_ns()
        push!(frame_compute_time_buffer, compute_time_end - compute_time_start)

        texture_upload_start_time = time_ns()
        update_back_buffer(image)
        texture_upload_end_time = time_ns()
        push!(texture_upload_time_buffer, texture_upload_end_time - texture_upload_start_time)

        GLFW.SwapBuffers(window)

        SI.reset!(user_input_state)

        GLFW.PollEvents()

        i = i + 1

        sleep(max(0.0, min_seconds_per_frame - (time_ns() - last(frame_time_stamp_buffer)) / 1e9))

        push!(frame_time_stamp_buffer, time_ns())
    end

    MGL.glDeleteVertexArrays(1, VAO_ref)
    MGL.glDeleteBuffers(1, VBO_ref)
    MGL.glDeleteBuffers(1, EBO_ref)
    MGL.glDeleteProgram(shader_program)

    GLFW.DestroyWindow(window)

    return nothing
end

start()
