# optional asserts
if !ismissing(get(ENV, "JULIA_NO_ASSERTIONS", missing))
    macro assert(args...) end
end

const Maybe{T} = Union{T, Nothing}