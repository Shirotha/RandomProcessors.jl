function reroll_lt(x)
    return roll -> roll <= x ? (nothing, 1) : roll
end

function reroll_gt(x)
    return roll -> roll >= x ? (nothing, 1) : roll
end

function reroll_eq(x)
    return roll -> roll == x ? (nothing, 1) : roll
end

function explode_gt(x)
    # TODO: option to only explode once
    return roll -> (roll, roll >= x ? 1 : 0)
end