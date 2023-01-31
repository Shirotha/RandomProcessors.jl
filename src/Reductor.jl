struct Reductor{T}
    processes::Vector

    function Reductor{T}(processes) where T
        @assert all(p -> hasmethod(p, Tuple{Vector{T}}), processes)
        # TODO: verify return type is ReductorResult{T}
        return new{T}(processes)
    end
end

Reductor{T}(p::Function) where T = Reductor{T}([p])
Reductor{T}(p, ps...) where T = Reductor{T}([p, ps...])
Reductor{T}(ps::Tuple) where T = Reductor{T}([ps...])

const ReductorResult{T} = Union{T, Vector{T}}
const ReductorSampler{T} = SamplerSimple{Reductor{T}, S} where S <: Sampler{Vector{T}}

# TODO: should this have access to a sampler (and which one?)
function (r::Reductor{T})(values::Vector{T})::T where T
    isdone(x) = true
    isdone(x::Vector) = length(x) <= 1
    result(x) = x
    function result(x::Vector)
        @assert length(x) == 1
        return first(x)
    end

    for p in r.processes
        presult = p(values)
        isdone(presult) && return result(presult)

        values = presult
    end
    return result(values)
end

eltype(::Type{Reductor{T}}) where T = T

function rand(rng::AbstractRNG, sampler::ReductorSampler{T}) where T
    reduce = sampler.self
    values_source = sampler.data
    values = rand(rng, values_source)
    return reduce(values)
end