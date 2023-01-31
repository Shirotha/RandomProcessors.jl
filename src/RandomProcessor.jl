struct RandomProcessor{T}
    value::ProcessedValue{T}
    reduce::Reductor{T}
    
    function RandomProcessor{T}(value, count; process=(), reduce=()) where T
        stack = ProcessStack{T}(process)
        process = ProcessedValue(value, count, stack)
        reductor = Reductor{T}(reduce)
        return new{T}(process, reductor)
    end
end

function Sampler(rng::AbstractRNG, proc::RandomProcessor, repetition::Repetition)
    sampler = Sampler(rng, proc.value, repetition)
    return SamplerSimple(proc.reduce, sampler)
end

function (proc::RandomProcessor{T})(; repeat=1, keep_naturals=false) where T
    nats = rand(proc.value, repeat)
    result = proc.reduce.(nats)
    if keep_naturals
        return result, nats
    else
        return result
    end
end