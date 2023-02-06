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
include("entity_component_system.jl")
include("utils.jl")

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

    show_debug_text = true
    debug_text_list = String[]

    # assets
    color_type = BinaryTransparentColor{CT.RGBA{FPN.N0f8}}
    texture_atlas = TextureAtlas(color_type[])

    # entities
    entities = Entity{Int}[]

    add_entity!(entities, Entity(
        true,
        SD.Point(1, 1),
        load_texture(texture_atlas, "assets/background.png"),
        null(AnimationState{Int}),
    ))

    add_entity!(entities, Entity(
        true,
        SD.Point(540, 960),
        load_texture(texture_atlas, "assets/burning_loop_1.png", length_scale = 4),
        AnimationState(1, 8, 100_000_000, 1),
    ))

    draw_list = Any[]

    ui_context = SI.UIContext(user_interaction_state, user_input_state, layout, COLORS, draw_list)

    i = 0

    sliding_window_size = 30

    max_frames_per_second = 60
    min_ns_per_frame = 1_000_000_000 ÷ max_frames_per_second

    reference_time = time_ns()

    frame_time_stamp_buffer = DS.CircularBuffer{Int}(sliding_window_size + 1)
    push!(frame_time_stamp_buffer, 0)
    push!(frame_time_stamp_buffer, 1)

    frame_compute_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(frame_compute_time_buffer, 0)

    texture_upload_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(texture_upload_time_buffer, 0)

    sleep_time_theoretical_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(sleep_time_theoretical_buffer, 0)

    sleep_time_observed_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(sleep_time_observed_buffer, 0)

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

        compute_time_start = get_time(reference_time)

        simulation_time = min_ns_per_frame

        animation_system!(entities, simulation_time)

        drawing_system!(draw_list, entities, texture_atlas)

        text = "Press the escape key to quit"
        SI.do_widget!(
            SI.TEXT,
            ui_context,
            SI.WidgetID(@__FILE__, @__LINE__, 1),
            text;
            alignment = SI.UP1_LEFT1,
        )

        push!(debug_text_list, "previous frame number: $(i)")

        push!(debug_text_list, "average total time spent per frame (averaged over previous $(length(frame_time_stamp_buffer) - 1) frames): $(round((last(frame_time_stamp_buffer) - first(frame_time_stamp_buffer)) / (1e6 * (length(frame_time_stamp_buffer) - 1)), digits = 2)) ms")

        push!(debug_text_list, "(avg. sleep time observed) - (avg. sleep time theoretical): $(round(sum(sleep_time_observed_buffer) / (1e6 * length(sleep_time_observed_buffer)) - sum(sleep_time_theoretical_buffer) / (1e6 * length(sleep_time_theoretical_buffer)), digits = 2)) ms")

        push!(debug_text_list, "average compute time spent per frame (averaged over previous $(length(frame_compute_time_buffer)) frames): $(round(sum(frame_compute_time_buffer) / (1e6 * length(frame_compute_time_buffer)), digits = 2)) ms")

        push!(debug_text_list, "average texture upload time spent per frame (averaged over previous $(length(texture_upload_time_buffer)) frames): $(round(sum(texture_upload_time_buffer) / (1e6 * length(texture_upload_time_buffer)), digits = 2)) ms")

        push!(debug_text_list, "simulation_time: $(simulation_time)")

        push!(debug_text_list, "entities[1]: $(entities[1])")

        push!(debug_text_list, "entities[2]: $(entities[2])")

        push!(debug_text_list, "length(entities): $(length(entities))")

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

        for drawable in draw_list
            SD.draw!(image, drawable)
        end
        empty!(draw_list)

        compute_time_end = get_time(reference_time)
        push!(frame_compute_time_buffer, compute_time_end - compute_time_start)

        texture_upload_start_time = get_time(reference_time)
        update_back_buffer(image)
        texture_upload_end_time = get_time(reference_time)
        push!(texture_upload_time_buffer, texture_upload_end_time - texture_upload_start_time)

        GLFW.SwapBuffers(window)

        SI.reset!(user_input_state)

        GLFW.PollEvents()

        i = i + 1

        sleep_time_theoretical = max(0, min_ns_per_frame - (get_time(reference_time) - last(frame_time_stamp_buffer)))
        push!(sleep_time_theoretical_buffer, sleep_time_theoretical)

        sleep_start_time = get_time(reference_time)
        sleep(sleep_time_theoretical / 1e9)
        sleep_end_time = get_time(reference_time)

        sleep_time_observed = (sleep_end_time - sleep_start_time)
        push!(sleep_time_observed_buffer, sleep_time_observed)

        push!(frame_time_stamp_buffer, get_time(reference_time))
    end

    MGL.glDeleteVertexArrays(1, VAO_ref)
    MGL.glDeleteBuffers(1, VBO_ref)
    MGL.glDeleteBuffers(1, EBO_ref)
    MGL.glDeleteProgram(shader_program)

    GLFW.DestroyWindow(window)

    return nothing
end

start()
