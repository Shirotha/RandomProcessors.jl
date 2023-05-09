include("header.jl")

const STAT_NAMES = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

function main()
    stats = @roll 4d6d1 + d20 repeat=length(STAT_NAMES)
    mods = (stats .- 10) .>> 1

    for i in eachindex(STAT_NAMES)
        println(STAT_NAMES[i], " ", stats[i], " (", mods[i], ")")
    end

    default = @Roller d20
    advantage = @Roller 2d20d1

    atk, nats = advantage(keep_naturals=true)
    nat = maximum(nats)
    print("attack roll at advantage: 2d20d1 + STR mod: ", nats, " + ", mods[1], " = ", atk + mods[1])
    if nat == 20
        println("(critical!)")
    elseif nat == 1
        println("(fumble!)")
    else
        println()
    end

    pool = @Roller "$(stats[1])d10"
    println("rolling [STR]d10 = $(stats[1])d10 = ", Base.@invokelatest pool())
    
    roll, nats = @roll "$(stats[4])d10" keep_naturals=true
    println("rolling [INT]d10 = $(stats[4])d10 = ", nats, " = ", roll)
end

main()