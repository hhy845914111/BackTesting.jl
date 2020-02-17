#=
using DataFrames

include("accounting.jl")
include("matching.jl")

module StrategyConfig
    const data_file_name = "50etf.csv";
    const initial_cash = 1000.0;
end


function on_tick(tdf::AbstractDataFrame, account::Account,
    ot_args...; ot_kwargs...)::OrderBook{PrivatePriceLevel}
    return Vector([Order("AAPL", 10, 90.1, :buy, now(), 1)]);
end
=#
