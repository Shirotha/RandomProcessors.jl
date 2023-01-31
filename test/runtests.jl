using Test

include("../src/RandomProcessors.jl")
using .RandomProcessors
using .RandomProcessors.Dice


@testset verbose=true "RandomProcessors" begin

    include("RandomProcessor.jl")
    include("Dice.jl")

end