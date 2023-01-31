@testset verbose=true "Dice" begin
    rolls, naturals = @roll 4d6d1 repeat=6 keep_naturals=true
    @show rolls naturals
    
    let roller = @Roller 2d20d1
        @show rand(roller, 5)
    end
end