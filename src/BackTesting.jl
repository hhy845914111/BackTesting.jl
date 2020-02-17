include("configure.jl")

include("orderbook.jl")
include("accounting.jl")
include("preprocessing.jl")
#export run_one_test


#function run_one_test(pre_args=(), pre_kwargs=(), ot_args=(), ot_kwargs=(), report_obj::T=TestReport where {T <: AbstractReport})::AbstractReport
#=
pre_args = ()
pre_kwargs = ()
ot_args = ()
ot_kwargs = ()

# 1. load market data
df = load_data(StrategyConfig.data_file_name);

# 2. carry out preprocessing
mkt_data_preprocessing!(df, pre_args...; pre_kwargs...);

# 3. make trading decisions
df_len = size(df)[1];
account = Account(StrategyConfig.initial_cash);

@inbound for idx = 1 : df_len
    tdf = @view df[1:idx, :];

    order_vec = on_tick(tdf, account, ot_args...; ot_kwargs...);
    if !(order_vec === nothing)
        matched_vec = match_order(order_vec, @view df[idx, :]);
        #book_trades!(matched_tpl, account);
    end

end

#    return report_obj(account);

#end
#end

run_one_test()
=#
