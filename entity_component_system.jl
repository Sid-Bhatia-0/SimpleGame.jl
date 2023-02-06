struct Entity{I}
    is_alive::Bool
    position::SD.Point{I}
    texture_index::TextureIndex{I}
    animation_state::AnimationState{I}
end

is_alive(entity) = entity.is_alive

is_drawable(entity) = entity.texture_index.start > zero(entity.texture_index.start)

is_animatable(entity) = entity.animation_state.num_frames > one(entity.animation_state.num_frames)

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

function animation_system!(entities, simulation_time)
    for (i, entity) in enumerate(entities)
        if is_alive(entity) && is_animatable(entity)
            entities[i] = typeof(entity)(
                entity.is_alive,
                entity.position,
                entity.texture_index,
                animate(entity.animation_state, simulation_time),
            )
        end
    end
end

function drawing_system!(draw_list, entities, texture_atlas)
    for (i, entity) in enumerate(entities)
        if is_alive(entity) && is_drawable(entity)
            if is_animatable(entity)
                push!(draw_list, SD.Image(entity.position, get_texture(texture_atlas, entity.texture_index, entity.animation_state)))
            else
                push!(draw_list, SD.Image(entity.position, get_texture(texture_atlas, entity.texture_index)))
            end
        end
    end
end
