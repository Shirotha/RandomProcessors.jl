include("header.jl")

const STAT_NAMES = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

stats = @roll 4d6d1 repeat=length(STAT_NAMES)
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