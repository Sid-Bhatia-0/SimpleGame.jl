import Accessors
import ModernGL as MGL
import DataStructures as DS
import GLFW
import SimpleDraw as SD
import SimpleIMGUI as SI
import FileIO
import ImageIO
import ColorTypes as CT
import FixedPointNumbers as FPN

const IS_DEBUG = true

mutable struct DebugInfo
    show_messages::Bool
    show_collision_boxes::Bool
    messages::Vector{String}
    frame_start_time_buffer::DS.CircularBuffer{Int}
    event_poll_time_buffer::DS.CircularBuffer{Int}
    dt_buffer::DS.CircularBuffer{Int}
    update_time_buffer::DS.CircularBuffer{Int}
    drawing_system_time_buffer::DS.CircularBuffer{Int}
    draw_time_buffer::DS.CircularBuffer{Int}
    texture_upload_time_buffer::DS.CircularBuffer{Int}
    buffer_swap_time_buffer::DS.CircularBuffer{Int}
    sleep_time_theoretical_buffer::DS.CircularBuffer{Int}
    sleep_time_observed_buffer::DS.CircularBuffer{Int}
end

function DebugInfo()
    show_messages = true
    show_collision_boxes = true
    messages = String[]
    sliding_window_size = 30

    frame_start_time_buffer = DS.CircularBuffer{Int}(sliding_window_size + 1)
    push!(frame_start_time_buffer, 0)

    event_poll_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(event_poll_time_buffer, 0)

    dt_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(dt_buffer, 0)

    update_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(update_time_buffer, 0)

    drawing_system_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(drawing_system_time_buffer, 0)

    draw_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(draw_time_buffer, 0)

    texture_upload_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(texture_upload_time_buffer, 0)

    sleep_time_theoretical_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(sleep_time_theoretical_buffer, 0)

    sleep_time_observed_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(sleep_time_observed_buffer, 0)

    buffer_swap_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(buffer_swap_time_buffer, 0)

    return DebugInfo(
        show_messages,
        show_collision_boxes,
        messages,
        frame_start_time_buffer,
        event_poll_time_buffer,
        dt_buffer,
        update_time_buffer,
        drawing_system_time_buffer,
        draw_time_buffer,
        texture_upload_time_buffer,
        buffer_swap_time_buffer,
        sleep_time_theoretical_buffer,
        sleep_time_observed_buffer,
    )
end

const DEBUG_INFO = DebugInfo()

include("opengl_utils.jl")
include("colors.jl")
include("collision_detection.jl")
include("textures.jl")
include("entity_component_system.jl")
include("utils.jl")

const PIXEL_LENGTH = 2^24

get_block_start(i_block, block_length) = (i_block - one(i_block)) * block_length + one(block_length)
get_block_end(i_block, block_length) = i_block * block_length + one(block_length)
get_block(x, block_length) = fld1(x, block_length)

get_block(vec::Vec, block_length) = Vec(get_block(vec.x, block_length), get_block(vec.y, block_length))

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

    # assets
    color_type = BinaryTransparentColor{CT.RGBA{FPN.N0f8}}
    texture_atlas = TextureAtlas(color_type[])

    # entities
    entities = Vector{Entity}(undef, MAX_ENTITIES)

    # background
    entities[Integer(INDEX_BACKGROUND)] = Entity(
        true,
        false,
        false,
        false,
        false,
        Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)),
        NULL_VELOCITY,
        NULL_COLLISION_BOX,
        STATIC,
        load_texture(texture_atlas, "assets/background.png"),
        null(AnimationState),
    )

    # player
    entities[Integer(INDEX_PLAYER)] = Entity(
        true,
        true,
        true,
        false,
        false,
        Vec(get_block_start(540, PIXEL_LENGTH), get_block_start(960, PIXEL_LENGTH)),
        Vec(0, 0),
        AABB(Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)), 32 * 4 * PIXEL_LENGTH, 24 * 4 * PIXEL_LENGTH),
        DYNAMIC,
        load_texture(texture_atlas, "assets/burning_loop_1.png", length_scale = 4),
        AnimationState(1, 8, 1000, 1),
    )

    # ground
    entities[Integer(INDEX_GROUND)] = Entity(
        true,
        false,
        false,
        true,
        false,
        Vec(get_block_start(975, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)),
        NULL_VELOCITY,
        AABB(Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)), 106 * PIXEL_LENGTH, 1920 * PIXEL_LENGTH),
        STATIC,
        null(TextureIndex),
        null(AnimationState),
    )

    # left boundary wall
    entities[Integer(INDEX_LEFT_BOUNDARY_WALL)] = Entity(
        true,
        false,
        false,
        false,
        false,
        Vec(get_block_start(1 - 64, PIXEL_LENGTH), get_block_start(1 - 64, PIXEL_LENGTH)),
        NULL_VELOCITY,
        AABB(Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)), (1080 + 2 * 64) * PIXEL_LENGTH, 64 * PIXEL_LENGTH),
        STATIC,
        null(TextureIndex),
        null(AnimationState),
    )

    # right boundary wall
    entities[Integer(INDEX_RIGHT_BOUNDARY_WALL)] = Entity(
        true,
        false,
        false,
        false,
        false,
        Vec(get_block_start(1 - 64, PIXEL_LENGTH), get_block_start(1920 + 1, PIXEL_LENGTH)),
        NULL_VELOCITY,
        AABB(Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)), (1080 + 2 * 64) * PIXEL_LENGTH, 64 * PIXEL_LENGTH),
        STATIC,
        null(TextureIndex),
        null(AnimationState),
    )

    # top boundary wall
    entities[Integer(INDEX_TOP_BOUNDARY_WALL)] = Entity(
        true,
        false,
        false,
        false,
        false,
        Vec(get_block_start(1 - 64, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)),
        NULL_VELOCITY,
        AABB(Vec(get_block_start(1, PIXEL_LENGTH), get_block_start(1, PIXEL_LENGTH)), 64 * PIXEL_LENGTH, 1920 * PIXEL_LENGTH),
        STATIC,
        null(TextureIndex),
        null(AnimationState),
    )

    draw_list = Any[]

    ui_context = SI.UIContext(user_interaction_state, user_input_state, layout, COLORS, draw_list)

    frame_number = 1

    max_frames_per_second = 60
    min_ns_per_frame = 1_000_000_000 ?? max_frames_per_second
    min_??s_per_frame = 1_000_000 ?? max_frames_per_second

    reference_time = time_ns()
    previous_frame_start_time = 0

    while !GLFW.WindowShouldClose(window)
        if IS_DEBUG
            empty!(DEBUG_INFO.messages)
        end

        frame_start_time = get_time(reference_time)
        previous_frame_end_time = frame_start_time
        previous_frame_time = previous_frame_end_time - previous_frame_start_time
        previous_frame_start_time = frame_start_time
        if IS_DEBUG
            push!(DEBUG_INFO.frame_start_time_buffer, frame_start_time)
        end

        event_poll_start_time = get_time(reference_time)
        GLFW.PollEvents()
        event_poll_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.event_poll_time_buffer, event_poll_end_time - event_poll_start_time)
        end

        if SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_ESCAPE) + 1])
            GLFW.SetWindowShouldClose(window, true)
            break
        end

        if SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_D) + 1])
            if IS_DEBUG
                DEBUG_INFO.show_messages = !DEBUG_INFO.show_messages
            end
        end

        if SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_C) + 1])
            if IS_DEBUG
                DEBUG_INFO.show_collision_boxes = !DEBUG_INFO.show_collision_boxes
            end
        end

        player = entities[2]
        key_up_ended_down = user_input_state.keyboard_buttons[Int(GLFW.KEY_UP) + 1].ended_down
        key_down_ended_down = user_input_state.keyboard_buttons[Int(GLFW.KEY_DOWN) + 1].ended_down

        key_up_went_down = SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_UP) + 1])
        key_down_went_down = SI.went_down(user_input_state.keyboard_buttons[Int(GLFW.KEY_DOWN) + 1])

        if key_up_went_down && !key_down_went_down
            entities[2] = (Accessors.@set player.velocity.x = -500_000)
        elseif !key_up_went_down && key_down_went_down
            entities[2] = (Accessors.@set player.velocity.x = 500_000)
        end

        player = entities[2]
        key_left_ended_down = user_input_state.keyboard_buttons[Int(GLFW.KEY_LEFT) + 1].ended_down
        key_right_ended_down = user_input_state.keyboard_buttons[Int(GLFW.KEY_RIGHT) + 1].ended_down

        if key_left_ended_down && !key_right_ended_down
            entities[2] = (Accessors.@set player.velocity.y = -500_000)
        elseif !key_left_ended_down && key_right_ended_down
            entities[2] = (Accessors.@set player.velocity.y = 500_000)
        else
            entities[2] = (Accessors.@set player.velocity.y = NULL_VELOCITY.y)
        end

        layout.reference_bounding_box = SD.Rectangle(SD.Point(1, 1), image_height, image_width)

        dt = previous_frame_time
        if IS_DEBUG
            push!(DEBUG_INFO.dt_buffer, dt)
        end

        update_start_time = get_time(reference_time)
        update!(entities, dt)
        update_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.update_time_buffer, update_end_time - update_start_time)
        end

        drawing_system_start_time = get_time(reference_time)
        drawing_system!(draw_list, entities, texture_atlas)
        drawing_system_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.drawing_system_time_buffer, drawing_system_end_time - drawing_system_start_time)
        end

        if IS_DEBUG
            push!(DEBUG_INFO.messages, "Press the escape key to quit")

            push!(DEBUG_INFO.messages, "previous frame number: $(frame_number)")

            push!(DEBUG_INFO.messages, "avg. total time per frame: $(round((last(DEBUG_INFO.frame_start_time_buffer) - first(DEBUG_INFO.frame_start_time_buffer)) / (1000 * length(DEBUG_INFO.frame_start_time_buffer) - 1), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. event poll time per frame: $(round(sum(DEBUG_INFO.event_poll_time_buffer) / (1000 * length(DEBUG_INFO.event_poll_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. dt per frame: $(round(sum(DEBUG_INFO.dt_buffer) / (1000 * length(DEBUG_INFO.dt_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. update time per frame: $(round(sum(DEBUG_INFO.update_time_buffer) / (1000 * length(DEBUG_INFO.update_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. drawing system time per frame: $(round(sum(DEBUG_INFO.drawing_system_time_buffer) / (1000 * length(DEBUG_INFO.drawing_system_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. draw time per frame: $(round(sum(DEBUG_INFO.draw_time_buffer) / (1000 * length(DEBUG_INFO.draw_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. texture upload time per frame: $(round(sum(DEBUG_INFO.texture_upload_time_buffer) / (1000 * length(DEBUG_INFO.texture_upload_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. sleep time theoretical: $(round(sum(DEBUG_INFO.sleep_time_theoretical_buffer) / (1000 * length(DEBUG_INFO.sleep_time_theoretical_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. sleep time observed: $(round(sum(DEBUG_INFO.sleep_time_observed_buffer) / (1000 * length(DEBUG_INFO.sleep_time_observed_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "avg. buffer swap time per frame: $(round(sum(DEBUG_INFO.buffer_swap_time_buffer) / (1000 * length(DEBUG_INFO.buffer_swap_time_buffer)), digits = 2)) ms")

            push!(DEBUG_INFO.messages, "length(entities): $(length(entities))")

            for (i, entity) in enumerate(entities)
                push!(DEBUG_INFO.messages, "entities[$(i)]: $(entities[i])")
            end

            if DEBUG_INFO.show_messages
                for (j, text) in enumerate(DEBUG_INFO.messages)
                    if isone(j)
                        alignment = SI.UP1_LEFT1
                    else
                        alignment = SI.DOWN2_LEFT1
                    end

                    SI.do_widget!(
                        SI.TEXT,
                        ui_context,
                        SI.WidgetID(@__FILE__, @__LINE__, j),
                        text;
                        alignment = alignment,
                    )
                end
            end
        end

        draw_start_time = get_time(reference_time)
        for drawable in draw_list
            if isa(drawable, ShapeDrawable)
                SD.draw!(image, drawable.shape, drawable.color)
            else
                SD.draw!(image, drawable)
            end
        end
        draw_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.draw_time_buffer, draw_end_time - draw_start_time)
        end
        empty!(draw_list)

        texture_upload_start_time = get_time(reference_time)
        update_back_buffer(image)
        texture_upload_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.texture_upload_time_buffer, texture_upload_end_time - texture_upload_start_time)
        end

        buffer_swap_start_time = get_time(reference_time)
        GLFW.SwapBuffers(window)
        buffer_swap_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.buffer_swap_time_buffer, buffer_swap_end_time - buffer_swap_start_time)
        end

        SI.reset!(user_input_state)

        frame_number = frame_number + 1

        sleep_time_theoretical = max(0, min_??s_per_frame - (get_time(reference_time) - frame_start_time))
        if IS_DEBUG
            push!(DEBUG_INFO.sleep_time_theoretical_buffer, sleep_time_theoretical)
        end

        sleep_start_time = get_time(reference_time)
        sleep(sleep_time_theoretical / 1e6)
        sleep_end_time = get_time(reference_time)
        if IS_DEBUG
            push!(DEBUG_INFO.sleep_time_observed_buffer, sleep_end_time - sleep_start_time)
        end
    end

    MGL.glDeleteVertexArrays(1, VAO_ref)
    MGL.glDeleteBuffers(1, VBO_ref)
    MGL.glDeleteBuffers(1, EBO_ref)
    MGL.glDeleteProgram(shader_program)

    GLFW.DestroyWindow(window)

    return nothing
end

start()
