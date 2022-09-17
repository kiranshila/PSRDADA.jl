using PSRDADA
using Test

@testset "PSRDADA.jl" begin
    for buf_count in [1, 5, 10, 100], buf_size in [1, 10, 100, 1000, 100000], type in [:data, :header]
        with_client(0xb0ba, buf_size, buf_count, buf_size, buf_count) do client
            data = [rand(UInt8, buf_size) for _ in 1:buf_count]
            with_write_iter(client; type=type) do wb
                for d in data
                    next(wb) .= d
                end
            end
            with_read_iter(client; type=type) do rb
                for i in 1:buf_count
                    @test data[i] == next(rb)
                end
            end
        end
    end
end
