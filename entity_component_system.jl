struct AnimationComponent{I}
    has_component::Bool
    animation_state::AnimationState{I}
end

struct DrawingComponent{I}
    has_component::Bool
    texture_index::TextureIndex{I}
end

struct EntityData{I}
    alive_statuses::BitVector
    animation_components::Vector{AnimationComponent{I}}
    drawing_components::Vector{DrawingComponent{I}}
end

function get_null(::Type{AnimationComponent{I}}) where {I}
    has_component = false
    animation_state = AnimationState(zero(I), zero(I), zero(I))
    return AnimationComponent(has_component, animation_state)
end

function get_null(::Type{DrawingComponent{I}}) where {I}
    has_component = false
    texture_index = TextureIndex(zero(I), zero(I), zero(I))
    return DrawingComponent(has_component, texture_index)
end

function EntityData(;max_entities = 1024, I = Int)
    alive_statuses = falses(max_entities)
    animation_components = fill(get_null(AnimationComponent{I}), max_entities)
    drawing_components = fill(get_null(DrawingComponent{I}), max_entities)

    return EntityData(
        alive_statuses,
        animation_components,
        drawing_components,
    )
end
