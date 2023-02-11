struct TextureIndex
    start::Int
    height::Int
    width::Int
end

struct AnimationState
    frame_number::Int
    num_frames::Int
    duration::Float64
    time_alive::Float64
end

struct TextureAtlas{C}
    data::Vector{C}
end

null(::Type{TextureIndex}) = TextureIndex(0, 0, 0)

null(::Type{AnimationState}) = AnimationState(0, 0, 0.0, 0.0)

function load_texture(texture_atlas, filename; length_scale = 1)
    data = texture_atlas.data
    C = eltype(texture_atlas.data)

    image = FileIO.load(filename)
    image_height, image_width = size(image)

    texture_start = length(data) + 1
    texture_height = image_height * length_scale
    texture_width = image_width * length_scale

    resize!(data, length(data) + texture_height * texture_width)

    texture = get_texture(data, texture_start, texture_height, texture_width)

    for j in axes(image, 2)
        for i in axes(image, 1)
            i_start = (i - one(i)) * length_scale + one(i)
            i_end = i_start + length_scale - one(i)

            j_start = (j - one(j)) * length_scale + one(j)
            j_end = j_start + length_scale - one(j)

            pixel_block = @view texture[i_start : i_end, j_start : j_end]

            fill!(pixel_block, C(image[i, j]))
        end
    end

    return TextureIndex(
        texture_start,
        texture_height,
        texture_width,
    )
end

function get_texture(data, start, height, width)
    texture_data = @view data[start : start + height * width - one(start)]

    return reshape(texture_data, height, width)
end

function get_texture(data, texture_start, texture_height, texture_width, frame_number, num_frames)
    frame_height = texture_height
    frame_width = texture_width ÷ num_frames

    frame_start = texture_start + (frame_number - one(frame_number)) * frame_height * frame_width

    frame_data = @view data[frame_start : frame_start + frame_height * frame_width - one(frame_start)]

    return reshape(frame_data, frame_height, frame_width)
end

get_texture(texture_atlas::TextureAtlas, texture_index::TextureIndex) = get_texture(texture_atlas.data, texture_index.start, texture_index.height, texture_index.width)

get_texture(texture_atlas::TextureAtlas, texture_index::TextureIndex, animation_state::AnimationState) = get_texture(texture_atlas.data, texture_index.start, texture_index.height, texture_index.width, animation_state.frame_number, animation_state.num_frames)

function get_frame_number(time_alive, num_frames, duration)
    i = round(Int, time_alive * num_frames / duration, RoundUp)
    frame_number = mod1(i, num_frames)
    return frame_number
end

function animate(animation_state, simulation_time)
    frame_number = animation_state.frame_number
    num_frames = animation_state.num_frames
    duration = animation_state.duration
    time_alive = animation_state.time_alive

    time_alive = time_alive + simulation_time
    frame_number = get_frame_number(time_alive, num_frames, duration)

    return typeof(animation_state)(
        frame_number,
        num_frames,
        duration,
        time_alive,
    )
end
