using MacroTools
using Random

using ..RandomProcessors

import Base: rand, eltype
import Random: Sampler, Repetition, SamplerSimple


import MacroTools: prewalk, postwalk, gensym_ids

export @Roller, Roller, @roll, roll