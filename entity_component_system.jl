struct SpriteComponent{I}
    has_component::Bool
    sprite::Sprite{I}
end

struct EntityData{I}
    alive_statuses::BitVector
    sprite_components::Vector{SpriteComponent{I}}
end

function get_null(::Type{SpriteComponent{I}}) where {I}
    has_component = false

    sprite = Sprite(
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
        zero(I),
    )

    return SpriteComponent(has_component, sprite)
end

function EntityData(;max_entities = 1024, I = Int)
    alive_statuses = falses(max_entities)
    sprite_components = fill(get_null(SpriteComponent{I}), max_entities)

    return EntityData(
        alive_statuses,
        sprite_components,
    )
end
