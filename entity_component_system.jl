struct Entity{I}
    is_alive::Bool
    sprite::Sprite{I}
end

function get_null(::Type{Entity{I}}) where {I}
    is_alive = false

    sprite = Sprite(
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
    )

    return Entity(is_alive, sprite)
end
