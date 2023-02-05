struct Entity{I}
    is_alive::Bool
    position::SD.Point{I}
    sprite::Sprite{I}
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
    position = entity.position
    sprite = entity.sprite

    new_sprite = animate(sprite, simulation_time)

    return Entity(
        is_alive,
        position,
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

function drawing_system!(image, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if entity.is_alive
            SD.draw!(image, SD.Image(entity.position, get_texture(texture_atlas, entity.sprite)))
        end
    end
end
