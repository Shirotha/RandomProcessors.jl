@testset verbose=true "RandomProcessor" begin
    let reroll_one = roll -> roll <= 1 ? (nothing, 1) : roll,
        delete_min = rolls -> sort(rolls)[2:end],
            proc_3d6 = RandomProcessor{Int}(1:6, 3, reduce = sum),
            proc_4d6d1 = RandomProcessor{Int}(1:6, 4, reduce = (delete_min, sum)),
            proc_4d6d1r1 = RandomProcessor{Int}(1:6, 4, process = reroll_one, reduce = (delete_min, sum))

        @test all(x -> 6 <= x <= 18, rand(proc_4d6d1r1, 100))

        let N = 100_000
            function report(name, proc)
                rolls = proc(repeat = N)

                avg = sum(rolls) / N
                var = sum(rolls .* rolls) / N
                err = sqrt(var - avg * avg)

                println("$name: $avg ± $err")

                return avg, err
            end

            avg1, err1 = report("3d6", proc_3d6)
            avg2, err2 = report("4d6d1", proc_4d6d1)
            avg3, err3 = report("4d6d1r1", proc_4d6d1r1)

            @test avg1 < avg2 < avg3
            @test err1 > err2 > err3
        end
    end
end