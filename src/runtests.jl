# test if orders generated are correct
include("configure.jl")
include("preprocessing.jl")
include("matching.jl")

using Serialization

df = load_data(StrategyConfig.data_folder, StrategyConfig.data_file_name, Symbol(10001875))
filter!(x -> x.BP2 > 0, df);
#=
@time odr_vec = gen_odrs(df, :sbc, Date(2020, 2, 5), 0.0001)

i = 0
for od in odr_vec
    if od.amt < 0
        global i += 1
    end
end

i
=#

using Statistics

function RRQ(p::AbstractVector, lag::Integer,
    p_l::AbstractFloat, p_h::AbstractFloat)::AbstractVector{Int}

    len = length(p)
    tmp_vec = zeros(Int, len)
    @inbounds @simd for i = lag : len
        rl, rh = quantile(p[i - lag + 1 : i], (p_l, p_h))
        if p[i] > rh
            tmp_vec[i] = -1
        elseif p[i] < rl
            tmp_vec[i] = 1
        else
            tmp_vec[i] = 0
        end
    end

    return tmp_vec
end


signal_vec = RRQ(df.LastPx, 200, 0.2, 0.8)

rt_vec = vcat(diff(log.(df.LastPx)), [0.0])

crt_vec = cumsum(rt_vec .* signal_vec)

using Plots

plot(crt_vec)
plot(cumsum(rt_vec))
crt_vec
