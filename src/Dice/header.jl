using MacroTools
using Random

using ..RandomProcessors

import Base: rand, eltype
import Random: Sampler, Repetition, SamplerSimple

import Base: esc
import MacroTools: prewalk, postwalk, gensym_ids

export @Roller, Roller, @roll, roll, @roll_str, @Roller_str