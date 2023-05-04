struct DiceExpression{T, N, F}
    rollers::NTuple{N, RandomProcessor{T}}
    reduce::F
end

DiceExpression(expr::Expr) = eval(:(@DiceExpression $(esc(expr))))
DiceExpression(s::AbstractString) = DiceExpression(Meta.parse(s))

# TODO: don't return a Vector when count==1
function (d::DiceExpression{T})(; repeat=1, keep_naturals=false) where T
    result(x) = x
    result(x::Tuple{T}) where T = result(first(x))
    result(x::Vector) = length(x) == 1 ? first(x) : x

    args = invoke.(d.rollers, Tuple{}; repeat, keep_naturals)
    if keep_naturals
        # NTuple{length(rollers), Vector{Tuple{T, Vector}}}
        return result(d.reduce.(first.(args)...)), result(last.(args))
    else
        # NTuple{length(rollers), Vector{T}}
        return result(d.reduce.(args...))
    end
end

# parsing
const ROLL_MOD = r"(.*?)(\d+)"
const ROLL_EXPRESSION = r"\Ad(\d+)((.*?\d+)*)\Z"

# expect expression like 2d20d1r1 + d4 - 2
macro DiceExpression(expr::Expr)
    args = Symbol[]
    rollers = RandomProcessor[]

    body = prewalk(expr) do x
        proc::Maybe{RandomProcessor} = nothing
        if @capture(x, n_Integer * roll_Symbol)
            proc = tryparse_roll(n, roll)
        elseif @capture(x, roll_Symbol)
            proc = tryparse_roll(1, roll)
        end
        isnothing(proc) && return x

        push!(rollers, proc)

        arg = gensym_ids(gensym(:arg))
        push!(args, arg)
        
        return arg
    end

    def = combinedef(Dict(
        :name => :reduce,
        :args => args,
        :kwargs => (),
        :body => body
    ))

    return quote
        let rollers = ($(rollers...),)
            $def
            DiceExpression(rollers, reduce)
        end
    end
end
macro DiceExpression(roll::Symbol)
    roller = tryparse_roll(1, roll)
    @assert !isnothing(roller)

    return quote
        let rollers = ($roller,)
            DiceExpression(rollers, identity)
        end
    end
end

const var"@Roller" = var"@DiceExpression"
Roller(s::AbstractString) = DiceExpression(s)

const MODIFIERS = Dict(
    "rl" => (reroll_lt, :process),
    "rh" => (reroll_gt, :process),
    "r" => (reroll_eq, :process),
    "!" => (explode_gt, :process),


    "dl" => (drop_lowest, :reductor),
    "dh" => (drop_highest, :reductor),
    "d" => (drop_lowest, :reductor),

    "kl" => (keep_lowest, :reductor),
    "kh" => (keep_highest, :reductor),
    "k" => (keep_highest, :reductor),
)
function tryparse_roll(count, roll::String)
    mat = match(ROLL_EXPRESSION, roll)
    isnothing(mat) && return nothing

    die = parse(Int, mat[1])

    process = Any[]
    reduce = Any[]
    for m in eachmatch(ROLL_MOD, mat[2])
        arg = parse(Int, m[2])

        f, t = MODIFIERS[m[1]]
        if t == :process
            push!(process, f(arg))
        else
            push!(reduce, f(arg))
        end
    end
    push!(reduce, sum)
    return RandomProcessor{Int}(1:die, count; process, reduce)
end
tryparse_roll(count, roll::Symbol) = tryparse_roll(count, string(roll))


roll(s::AbstractString) = DiceExpression(s)()
roll(s::AbstractString, repeat; keep_naturals::Bool=false) = DiceExpression(s)(; repeat, keep_naturals)

macro roll(expr, args...)
    return quote
        let dice = @DiceExpression $(expr)
            dice(; $(esc.(args)...))
        end
    end
end

struct RandomFunction{F}
    f::F
end
(rf::RandomFunction)(args...) = rf.f(args...)

const DiceExpressionSampler{F, T} = SamplerSimple{RandomFunction{F}, T}

eltype(::Type{DiceExpression{T, N, F}}) where {T, N, F} = eltype(F)

function Sampler(rng::AbstractRNG, expr::DiceExpression, repetition::Repetition)
    samplers = Sampler.((rng,), expr.rollers, (repetition,))
    f = RandomFunction(expr.reduce)
    return SamplerSimple(f, samplers)
end

function rand(rng::AbstractRNG, expr::DiceExpressionSampler)
    f = expr.self
    samplers = expr.data
    args = rand.((rng,), samplers)
    return f(args...)
end