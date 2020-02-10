include("configure.jl")

using Dates: hour, minute, second, Time, Date
using CSV: read
using Distributed
addprocs(FMConfig.process_count)
@everywhere begin
    include("orderbook.jl")
    using Dates: Date
    using DataFrames
    using DataStructures: enqueue!, dequeue!
    using Random: shuffle
end


function load_data(data_folder::AbstractString, data_file::AbstractString,
    inst_id::Symbol)::AbstractDataFrame

    data_df = read("$data_folder/$data_file")

    rename!(data_df,
        [:InstID, :LastPx, :OpenPx, :HighPx, :LowPx, :Volume, :Turnover, :OI,
        :UpperLmt, :LowerLmt, :UpdateTime, :UpdateMillisec, :BP1, :BV1, :AP1, :AV1,
        :BP2, :BV2, :AP2, :AV2, :BP3, :BV3, :AP3, :AV3, :BP4, :BV4, :AP4, :AV4,
        :BP5, :BV5, :AP5, :AV5]
    )

    data_df.InstID = Symbol.(data_df.InstID)
    data_df = data_df[data_df.InstID .== inst_id, :]

    convert_time(x, y) = Time(hour(x), minute(x), second(x), y)
    data_df.tm = convert_time.(data_df[!, :UpdateTime], data_df[!, :UpdateMillisec])

    select!(data_df, Not([:OpenPx, :HighPx, :LowPx, :Turnover, :UpdateTime, :UpdateMillisec, :InstID]))
    div2int(x, y) = Int(div(x, y))

    data_df[!, :LastPx] = @. div2int(data_df[!, :LastPx], 0.0001)
    data_df[!, :UpperLmt] = @. div2int(data_df[!, :UpperLmt], 0.0001)
    data_df[!, :LowerLmt] = @. div2int(data_df[!, :LowerLmt], 0.0001)
    for i = 1 : 5
        tsb = Symbol("BP$i")
        data_df[!, tsb] = @. div2int(data_df[!, tsb], 0.0001)

        tsb = Symbol("AP$i")
        data_df[!, tsb] = @. div2int(data_df[!, tsb], 0.0001)
    end

    return data_df;
end


@inline function build_ob(dr::DataFrameRow, tkr::Symbol, dt::Date,
    p_l::Int, p_h::Int, ob_levels::Integer=5)::OrderBook

    ob = OrderBook(tkr, p_l, p_h)

    @inbounds for i = 1 : ob_levels
        tp = getproperty(dr, Symbol("BP$i"))
        enqueue!(ob.b_ld[tp],
            ReceivedOdr(tkr, getproperty(dr, Symbol("BV$i")), tp,
                DateTime(dt, dr.tm), :buy, :public, get_uuid())
        )

        tp = getproperty(dr, Symbol("AP$i"))
        enqueue!(ob.a_ld[tp],
            ReceivedOdr(tkr, getproperty(dr, Symbol("AV$i")), tp,
                DateTime(dt, dr.tm), :sell, :public, get_uuid())
        )
    end

    ob.b_top = dr.BP1
    ob.a_top = dr.AP1

    return ob
end


@everywhere function gen_odrs(r_od::DataFrameRow, r_nw::DataFrameRow, tkr::Symbol, dt::Date,
    rg::StepRange{Int, Int}, ob_levels::Integer=5)::AbstractVector{Order}

    @inline mk_dct(r, sd) = Dict(
        Pair.(
            values(r[[Symbol("$sd"*"P"*"$i") for i in 2 : ob_levels]]),
            values(r[[Symbol("$sd"*"V"*"$i") for i in 2 : ob_levels]])
        )
    )

    @inline ch2sym(ch) = ch == "B" ? :buy : :sell

    o_v = Vector{Order}()

    for (sd, rg) in (("B", rg), ("A", rg))
        o_dct = mk_dct(r_od, sd)
        n_dct = mk_dct(r_nw, sd)

        n_dct[r_od[Symbol("$sd"*"P1")]] = r_od[Symbol("$sd"*"P1")]

        for p in rg
            if p in keys(n_dct)
                if p in keys(o_dct)
                    if n_dct[p] > o_dct[p]
                        push!(o_v, Order(tkr, n_dct[p] - o_dct[p], p, ch2sym(sd),
                            :submit, DateTime(dt, r_nw.tm), :public, get_uuid())
                        )
                    elseif n_dct[p] < o_dct[p]
                        push!(o_v, Order(tkr, o_dct[p] - n_dct[p], p, ch2sym(sd),
                            :cancel, DateTime(dt, r_nw.tm), :public, get_uuid())
                        )
                    end
                else
                    push!(o_v, Order(tkr, n_dct[p], p, ch2sym(sd),
                        :submit, DateTime(dt, r_nw.tm), :public, get_uuid())
                    )
                end
            else
                if p in keys(o_dct)
                    push!(o_v, Order(tkr, o_dct[p], p, ch2sym(sd), :cancel,
                        DateTime(dt, r_nw.tm), :public, get_uuid())
                    )
                end
            end
        end
    end

    return o_v
end


function gen_odrs(mdf::AbstractDataFrame, tkr::Symbol, dt::Date,
    p_e::Float64, ob_levels::Integer=5)::AbstractVector{Order}

    len = size(mdf)[1]

    p_l = minimum(mdf[!, :LowerLmt])
    p_h = maximum(mdf[!, :UpperLmt])

    odr_vec = @sync @inbounds @distributed vcat for i = 2 : len
        r_od = mdf[i - 1, :]
        r_nw = mdf[i, :]

        t_odr_vec = Vector{Order}()


        if r_nw.LastPx > r_od.LastPx
            push!(t_odr_vec, Order(tkr, r_nw.Volume - r_od.Volume, r_nw.LastPx, :buy,
                :submit, DateTime(dt, r_nw.tm), :public, get_uuid())
            )
        elseif r_nw.LastPx < r_od.LastPx
            push!(t_odr_vec, Order(tkr, r_nw.Volume - r_od.Volume, r_nw.LastPx, :sell,
                :submit, DateTime(dt, r_nw.tm), :public, get_uuid())
            )
        end

        vcat(t_odr_vec, shuffle(gen_odrs(r_od, r_nw, tkr, dt,
            p_l : 1 : p_h, ob_levels))
        )
    end

    return odr_vec
end


function mkt_data_preprocessing!(df::AbstractDataFrame)::Nothing

end

# test starts

# test ends
