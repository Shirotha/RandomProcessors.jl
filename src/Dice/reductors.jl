function drop_lowest(n)
    return rolls -> begin
        order = sortperm(rolls)
        I = sort(order[(n + 1):end])
        return rolls[I]
    end
end

function drop_highest(n)
    return rolls -> begin
        order = sortperm(rolls)
        I = sort(order[begin:end-n])
        return rolls[I]
    end
end

function keep_highest(n)
    return rolls -> begin
        order = sortperm(rolls)
        I = sort(order[end-(n - 1):end])
        return rolls[I]
    end
end

function keep_lowest(n)
    return rolls -> begin
        order = sortperm(rolls)
        I = sort(order[begin:begin+(n - 1)])
        return rolls[I]
    end
end