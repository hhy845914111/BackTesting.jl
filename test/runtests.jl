# test if orders generated are correct
include("preprocessing.jl")
include("matching.jl")

using Serialization

df = load_data(StrategyConfig.data_folder, StrategyConfig.data_file_name, Symbol(10001875))
filter!(x -> x.BP2 > 0, df);
@time odr_vec = gen_odrs(df, :sbc, Date(2020, 2, 5), 0.0001)

i = 0
for od in odr_vec
    if od.amt < 0
        global i += 1
    end
end

i
