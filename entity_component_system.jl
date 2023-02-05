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

function add_entity!(entities, entity)
    for (i, entity_i) in enumerate(entities)
        if !entity_i.is_alive
            entities[i] = entity
            return i
        end
    end

    push!(entities, entity)
    return length(entities)
end

function animate(entity::Entity, simulation_time)
    is_alive = entity.is_alive
    sprite = entity.sprite

    new_sprite = animate(sprite, simulation_time)

    return Entity(
        is_alive,
        new_sprite,
    )
end

function animation_system!(entities, simulation_time)
    for (i, entity) in enumerate(entities)
        if entity.is_alive
            entities[i] = animate(entity, simulation_time)
        end
    end
end
