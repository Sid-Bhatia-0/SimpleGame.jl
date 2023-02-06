struct Entity{I}
    is_alive::Bool
    position::SD.Point{I}
    sprite::Sprite{I}
end

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.sprite.start > zero(entity.sprite.start)

is_animatable(entity) = entity.sprite.num_frames > one(entity.sprite.num_frames)

function add_entity!(entities, entity)
    for (i, entity_i) in enumerate(entities)
        if !is_alive(entity_i)
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
        if is_alive(entity) && is_animatable(entity)
            entities[i] = animate(entity, simulation_time)
        end
    end
end

function drawing_system!(draw_list, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if is_alive(entity) && is_drawable(entity)
            push!(draw_list, SD.Image(entity.position, get_texture(texture_atlas, entity.sprite)))
        end
    end
end
