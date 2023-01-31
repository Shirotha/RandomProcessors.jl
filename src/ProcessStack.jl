struct ProcessStack{T}
    processes::Vector

    function ProcessStack{T}(processes) where T
        @assert all(p -> hasmethod(p, Tuple{T}), processes)
        # TODO: verify return type is ProcessResult{T}
        return new{T}(processes)
    end
end

ProcessStack{T}() where T = ProcessStack{T}([])
ProcessStack{T}(p::Function) where T = ProcessStack{T}([p])
ProcessStack{T}(p, ps...) where T = PrcessStack{T}([p, ps...])
ProcessStack{T}(ps::Tuple) where T = ProcessStack{T}([ps...])

const ProcessResult{T} = Union{Maybe{T}, Tuple{Maybe{T}, Int}}
const ProcessSampler{T} = SamplerSimple{ProcessStack{T}, Tuple{S, Int}} where S <: Sampler{T}

function (ps::ProcessStack{T})(value::T)::Tuple{Maybe{T}, Int} where T
    iscanceled((value, reroll)::Tuple) = isnothing(value)
    iscanceled(value) = isnothing(value)

    getvalue((value, reroll)::Tuple) = value
    getvalue(value) = value

    getrerolls((value, reroll)::Tuple) = reroll
    getrerolls(value) = 0

    rerolls = 0
    for p in ps.processes
        presult = p(value)
        rerolls += getrerolls(presult)

        iscanceled(presult) && return nothing, rerolls
        value = getvalue(value)
    end
    return value, rerolls
end

eltype(::Type{ProcessStack{T}}) where T = Vector{T}

function rand(rng::AbstractRNG, sampler::ProcessSampler{T}) where T
    processes = sampler.self
    value_source, count = sampler.data
    
    result = T[]
    while count > 0
        count -= 1

        value = rand(rng, value_source)
        value, rerolls = processes(value)

        count += rerolls
        isnothing(value) || push!(result, value)
    end
    return result
end