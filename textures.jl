struct TextureIndex{I}
    start::I
    height::I
    width::I
end

struct TextureAtlas{C}
    data::Vector{C}
end

function load_texture(texture_atlas, filename; num_frames = 1)
    image = FileIO.load(filename)

    start = length(texture_atlas.data) + 1
    height, width = size(image)

    @assert width % num_frames == 0
    width = width ÷ num_frames

    C = eltype(texture_atlas.data)

    for color in image
        push!(texture_atlas.data, C(color))
    end

    return TextureIndex(start, height, width)
end

function get_texture(texture_atlas, texture_index, animation_frame = 1)
    start = texture_index.start
    height = texture_index.height
    width = texture_index.width

    start = start + (animation_frame - one(animation_frame)) * height * width

    image_view = @view texture_atlas.data[start : start + height * width - one(start)]

    return reshape(image_view, height, width)
end
