using PSRDADA
using Test

@testset "PSRDADA.jl" begin
    for buf_count in [1, 5, 10, 100], buf_size in [1, 10, 100, 1000, 100000]
        client = client_create(0xb0ba, buf_size, buf_count, 1, 1)

        data = [rand(UInt8, buf_size) for _ in 1:buf_count]

        let wb = data_write(client)
            for d in data
                next(wb) .= d
            end
            finalize(wb)
        end

        let rb = data_read(client)
            for i in 1:buf_count
                @test data[i] == next(rb)
            end
            finalize(rb)
        end
        finalize(client)
    end
end
