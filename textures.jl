struct TextureIndex{I}
    start::I
    height::I
    width::I
end

struct AnimationState{I}
    num_frames::I
    animation_speed::I
    time_alive::I
end

struct TextureAtlas{C}
    data::Vector{C}
end

function load_texture(texture_atlas, filename; num_frames = 1, length_scale = 1)
    texture_data = texture_atlas.data

    image = FileIO.load(filename)

    texture_start = length(texture_data) + 1
    image_height, image_width = size(image)

    @assert image_width % num_frames == 0
    frame_height = image_height * length_scale
    frame_width = (image_width ÷ num_frames) * length_scale

    C = eltype(texture_atlas.data)

    resize!(texture_data, length(texture_data) + image_height * length_scale * image_width * length_scale)

    texture = reshape(
        @view(texture_data[texture_start : texture_start + image_height * length_scale * image_width * length_scale - one(texture_start)]),
        image_height * length_scale,
        image_width * length_scale,
    )

    for j in 1:image_width
        for i in 1:image_height
            i_start = (i - one(i)) * length_scale + one(i)
            i_end = i_start + length_scale - one(i)

            j_start = (j - one(j)) * length_scale + one(j)
            j_end = j_start + length_scale - one(j)

            pixel_block = @view texture[i_start : i_end, j_start : j_end]

            fill!(pixel_block, C(image[i, j]))
        end
    end

    return TextureIndex(texture_start, frame_height, frame_width)
end

function get_texture(texture_atlas, texture_index; frame_number = 1)
    start = texture_index.start
    height = texture_index.height
    width = texture_index.width

    start = start + (frame_number - one(frame_number)) * height * width

    image_view = @view texture_atlas.data[start : start + height * width - one(start)]

    return reshape(image_view, height, width)
end
