struct TextureIndex{I}
    start::I
    height::I
    width::I
end

struct TextureAtlas{C}
    data::Vector{C}
end

function load_texture(texture_atlas, filename)
    image = FileIO.load("assets/background.png")

    start = length(texture_atlas.data) + 1
    height, width = size(image)

    C = eltype(texture_atlas.data)

    for color in image
        push!(texture_atlas.data, C(color))
    end

    return TextureIndex(start, height, width)
end

function get_texture(texture_atlas, texture_index)
    start = texture_index.start
    height = texture_index.height
    width = texture_index.width

    image_view = @view texture_atlas.data[start : start + height * width - one(start)]

    return reshape(image_view, height, width)
end
