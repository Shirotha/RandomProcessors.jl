struct DiceExpression{T, N, F}
    rollers::NTuple{N, RandomProcessor{T}}
    reduce::F
end
DiceExpression(rollers::Tuple{}, reduce::F) where F =
    DiceExpression{first(Base.return_types(reduce)), 0, F}(rollers, reduce)

_result(x) = x
_result(x::Tuple{T}) where T = _result(first(x))
_result(x::Vector) = length(x) == 1 ? first(x) : x
_reduce(args::NTuple{N, Vector{T}}, reduce) where {N, T} =
    _result(reduce.(args...))
_reduce(args::NTuple{N, Tuple{Vector{T}, Vector{Vector{T}}}}, reduce) where {N, T} =
    (_result(reduce.(first.(args)...)), _result(last.(args)))
_reduce(::Tuple{}, reduce) = _result(reduce())

# TODO: don't return a Vector when count==1
function (d::DiceExpression{T})(rng=Random.GLOBAL_RNG; repeat=1, keep_naturals=false) where T
    args = invoke.(d.rollers, Tuple{AbstractRNG}, rng; repeat, keep_naturals)
    return _reduce(args, d.reduce)
end

# parsing
const ROLL_MOD = r"(.*?)(\d+)"
const ROLL_EXPRESSION = r"\Ad(\d+)((.*?\d+)*)\Z"

function extract_rollers(expr)
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

        arg = gensym(:arg)
        push!(args, arg)
        
        return arg
    end

    return Dict(
        :name => :reduce,
        :args => args,
        :kwargs => (),
        :body => body,
        :rollers => rollers
    )
end

# expect expression like 2d20d1r1 + d4 - 2
macro DiceExpression(expr)
    if @capture(expr, s_string)
        @esc s
        return quote
            let s = $s
                @eval @Roller $((Expr(:$, :s)))
            end
        end
    end
    expr, _ = unesc(expr)
    expr isa String && (expr = Meta.parse(expr))

    data = extract_rollers(expr)
    def = combinedef(data)
    
    return quote
        let rollers = ($(data[:rollers]...),)
            $def
            DiceExpression(rollers, reduce)
        end
    end
end
macro DiceExpression(s::String)
    expr = Meta.parse(s)
    return quote
        @Roller $expr
    end
end

const var"@Roller" = var"@DiceExpression"

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

function esc(expr, levels::Integer)
    levels <= 0 && return expr
    for _ in 1:levels
        expr = esc(expr)
    end
    return expr
end
function unesc(expr)
    levels = 0
    while @capture(expr, escexpr_escape)
        expr = first(escexpr.args)
        levels += 1
    end
    return expr, levels
end
function esc_assign(expr, levels=1)
    @assert @capture expr name_ = value_
    name = esc(name, levels)
    value = esc(value, levels)
    return :($name = $value)
end
function unesc_assign(expr)
    @assert @capture expr name_ = value_
    levels = 0
    while @capture(name, escname_escape)
        @assert @capture value escvalue_escape
        name = first(escname.args)
        value = first(escvalue.args)
        levels += 1
    end
    return :($name = $value), levels
end

macro roll(expr, kwargs...)
    if @capture(expr, s_string)
        @esc s
        kwargs = esc_assign.(kwargs)
        return quote
            let s = $s
                @eval @roll $((Expr(:$, :s))) $(kwargs...)
            end
        end
    end

    expr, exprlevels = unesc(expr)
    if !isempty(kwargs)
        unescaped = unesc_assign.(kwargs)
        @assert allequal(last.(unescaped))
        levels = max(last(first(unescaped)), 1)
        kwargs = first.(unescaped)
    else
        levels = exprlevels + 1
    end
    expr isa String && (expr = Meta.parse(expr))

    data = extract_rollers(expr)
    names = namify.(kwargs)

    :repeat in names || (kwargs = (kwargs..., :(repeat = 1)))
    :keep_naturals in names || (kwargs = (kwargs..., :(keep_naturals = false)))

    kwargs = esc_assign.(kwargs, levels)
    names = esc.(namify.(kwargs), levels)
    body = esc(data[:body], levels)
    args = esc.(data[:args], levels)
    rollers = data[:rollers]
    keep_naturals = esc(:keep_naturals, levels)
    repeat = esc(:repeat, levels)
    return quote
        let $(kwargs...), rolls = invoke.(($(rollers...),), Tuple{}; $(names...))
            if $keep_naturals
                result = _result([$body for ($(args...),) in zip(first.(rolls)...)])
                naturals = _result(last.(rolls))
                (result, naturals)
            else
                _result([$body for ($(args...),) in zip(rolls...)])
            end
        end
    end
end
macro roll(expr::String, kwargs...)
    expr = esc(Meta.parse(expr))
    kwargs = esc_assign.(kwargs)
    return quote
        @roll $expr $(kwargs...)
    end
end

macro roll_str(s)
    expr = esc(s)
    return quote
        @roll $expr
    end
end
macro Roller_str(s)
    expr = esc(s)
    return quote
        @Roller $expr
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