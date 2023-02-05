struct Sprite{I}
    start::I
    height::I
    width::I
    frame_number::I
    num_frames::I
    time_per_frame::I
    time_alive::I
end

struct TextureAtlas{C}
    data::Vector{C}
end

function load_texture(texture_atlas, filename; num_frames = 1, length_scale = 1, time_per_frame = 100_000_000, time_alive = 1)
    texture_data = texture_atlas.data
    C = eltype(texture_atlas.data)

    image = FileIO.load(filename)
    image_height, image_width = size(image)

    sprite_start = length(texture_data) + 1

    @assert iszero(mod(image_width, num_frames))
    sprite_height = image_height * length_scale
    sprite_width = (image_width ÷ num_frames) * length_scale

    resize!(texture_data, length(texture_data) + sprite_height * sprite_width * num_frames)

    texture = reshape(
        @view(texture_data[sprite_start : sprite_start + sprite_height * sprite_width * num_frames - one(sprite_start)]),
        sprite_height,
        sprite_width * num_frames,
    )

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

    return Sprite(
        sprite_start,
        sprite_height,
        sprite_width,
        one(sprite_start),
        num_frames,
        time_per_frame,
        time_alive,
    )
end

function get_texture(texture_atlas, sprite)
    start = sprite.start
    height = sprite.height
    width = sprite.width
    frame_number = sprite.frame_number

    start = start + (frame_number - one(frame_number)) * height * width

    image_view = @view texture_atlas.data[start : start + height * width - one(start)]

    return reshape(image_view, height, width)
end

function animate(sprite, simulation_time)
    start = sprite.start
    height = sprite.height
    width = sprite.width
    frame_number = sprite.frame_number
    num_frames = sprite.num_frames
    time_per_frame = sprite.time_per_frame
    time_alive = sprite.time_alive

    if num_frames == one(num_frames)
        return sprite
    else
        time_alive = time_alive + simulation_time
        time_alive_wrapped = mod1(time_alive, num_frames * time_per_frame)
        frame_number = div(time_alive_wrapped, time_per_frame, RoundUp)

        return Sprite(
            start,
            height,
            width,
            frame_number,
            num_frames,
            time_per_frame,
            time_alive,
        )
    end
end
