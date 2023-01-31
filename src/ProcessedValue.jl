struct ProcessedValue{T, D}
    value::D
    count::Int
    processes::ProcessStack{T}

    function ProcessedValue(value::D, count, processes::ProcessStack{T}) where {D, T}
        @assert count >= 1
        @assert rand(value) isa T
        new{T, D}(value, count, processes)
    end
end

eltype(::Type{<:ProcessedValue{T}}) where T = Vector{T}

function Sampler(rng::AbstractRNG, value::ProcessedValue{T}, ::Repetition) where T
    sampler = Sampler(rng, value.value, Val{Inf}())
    return SamplerSimple(value.processes, (sampler, value.count))
end