include("orderbook.jl")

using Dates: DateTime, now
using DataStructures: OrderedDict, Queue, enqueue!, dequeue!


@enum CrossSign cross_buy = -1 cross_sell = 1


@inline function match_submit_odr!(r_odr::ReceivedOdr, odr_fs::AbstractVector{OrderFill},
    dt::DateTime,
    n_ld::OrderedDict{Int, Queue{ReceivedOdr}},
    f_ld::OrderedDict{Int, Queue{ReceivedOdr}},
    n_top::Int, f_top::Int, ss::CrossSign)::Tuple{Int, Int}

    ssi = Int(ss)

    if ssi * r_odr.p < ssi * f_top
        enqueue!(n_ld[r_odr.p], r_odr)
        n_top = ssi * max(ssi * r_odr.p, ssi * n_top)
    else
        f_ep = ssi * maximum(ssi .* keys(f_ld))
        n_ep = -ssi * maximum(-ssi .* keys(n_ld))

        tp = f_top
        lv = f_ld[tp]
        top_odr = first(lv)
        t_amt = top_odr.amt
        t_val = top_odr.amt * top_odr.p
        while t_amt < r_odr.amt
            top_odr = dequeue!(lv)
            push!(odr_fs, OrderFill(top_odr, top_odr.amt, tp, dt))

            ps = tp : ssi : r_odr.p
            tp = f_top = find_next_level(f_ld, ps)

            if !(tp in ps)
                r_odr.amt -= t_amt
                push!(odr_fs, OrderFill(r_odr, t_amt, t_val / t_amt, dt))
                enqueue!(n_ld[tp - ssi], r_odr)
                n_top = tp - ssi
                f_top = find_next_level(f_ld, tp : ssi : f_ep)
                return n_top, f_top
            end

            lv = f_ld[tp]
            top_odr = first(lv)
            t_amt += top_odr.amt
            t_val += top_odr.amt * top_odr.p
        end

        res = t_amt - r_odr.amt
        t_val -= res * top_odr.p
        push!(odr_fs, OrderFill(top_odr, top_odr.amt - res, tp, dt))
        if res > 0
            top_odr.amt = res
        else
            dequeue!(lv)
            f_top = find_next_level(f_ld, tp : ssi : f_ep)
        end
        push!(odr_fs, OrderFill(r_odr, r_odr.amt, t_val / r_odr.amt, dt))
    end

    return n_top, f_top
end


@inline function match_cancel_odr(r_odr::ReceivedOdr, odr_fs::AbstractVector{OrderFill},
    dt::DateTime,
    ld::OrderedDict{Int, Queue{ReceivedOdr}},
    top::Int, ss::CrossSign)::Int

    ssi = Int(ss)

    tq = Queue{ReceivedOdr}()
    t_amt = 0
    lv = ld[r_odr.p]
    while !isempty(lv)
        rd_odr = dequeue!(lv)
        if rd_odr.usr == r_odr.usr && t_amt < r_odr.amt
            n_amt = t_amt + rd_odr.amt
            if n_amt < r_odr.amt
                push!(odr_fs, OrderFill(rd_odr, -rd_odr.amt, rd_odr.p, dt))
                t_amt = n_amt
            else
                push!(odr_fs, OrderFill(rd_odr, t_amt - r_odr.amt, rd_odr.p, dt))
                rd_odr.amt = n_amt - r_odr.amt
                t_amt = r_odr.amt
                enqueue!(tq, rd_odr)
            end
        else
            enqueue!(tq, rd_odr)
        end
    end

    top = find_next_level(ld, top : ssi : ssi * maximum(ssi .* keys(ld)))

    ld[r_odr.p] = tq
    push!(odr_fs, OrderFill(r_odr, t_amt, -1, dt))
    return top
end


function match_odr!(ob::OrderBook, odr::Order)::AbstractVector{OrderFill}
    odr_fs = Vector{OrderFill}()
    dt = now()

    r_odr = ReceivedOdr(odr.tkr, odr.amt, odr.p, dt, odr.side, odr.usr, odr.uuid)
    if odr.action == :submit
        if odr.side == :buy
            ob.b_top, ob.a_top = match_submit_odr!(r_odr, odr_fs, dt, ob.b_ld,
                ob.a_ld, ob.b_top, ob.a_top, cross_sell
            )
        else
            ob.a_top, ob.b_top = match_submit_odr!(r_odr, odr_fs, dt, ob.a_ld,
                ob.b_ld, ob.a_top, ob.b_top, cross_buy
            )
        end
    else
        if odr.side == :buy
            ob.b_top = match_cancel_odr(r_odr, odr_fs, dt, ob.b_ld, ob.b_top,
                cross_buy
            )
        else
            ob.a_top = match_cancel_odr(r_odr, odr_fs, dt, ob.a_ld, ob.a_top,
                cross_sell
            )
        end
    end

    return odr_fs
end


# test codes starts
#=
o_tob = OrderBook(:aapl, 0, 10)
n_tob = deepcopy(o_tob)

enqueue!(n_tob.b_ld[2], ReceivedOdr(:aapl, 20, 2, now(), :buy, :my, get_uuid()))
enqueue!(n_tob.b_ld[4], ReceivedOdr(:aapl, 10, 4, now(), :buy, :my, get_uuid()))
enqueue!(n_tob.a_ld[5], ReceivedOdr(:aapl, 10, 5, now(), :sell, :my, get_uuid()))
enqueue!(n_tob.a_ld[7], ReceivedOdr(:aapl, 20, 7, now(), :sell, :my, get_uuid()))

n_tob.b_top = 4
n_tob.a_top = 5

gen_odrs(o_tob, n_tob, :public)
gen_odrs(n_tob, o_tob, :public)


tod1 = Order(:aapl, 100, 8, :buy, :submit, now(), :my, get_uuid())
tod2 = Order(:aapl, 100, 1, :sell, :submit, now(), :my, get_uuid())
tod3 = Order(:aapl, 30, 4, :buy, :cancel, now(), :my, get_uuid())

match_odr!(tod3, n_tob)
n_tob.b_top
n_tob.a_top

match_odr!(tod1, n_tob)
n_tob.b_top
n_tob.a_top
n_tob.b_ld[8]

match_odr!(tod2, n_tob)
n_tob.b_top
n_tob.a_top
n_tob.a_ld[2]

using Serialization

#=
include("preprocessing.jl");
filter!(x -> x.BP2 > 0, df);
@time odr_vec = gen_odrs(df, :sbc, Date(2020, 2, 5), 0.0001)

serialize("C:\\Users\\hoore\\Documents\\data\\odrs.data", odr_vec)
init_ob = build_ob(df[1, :], :aapl, Date(2020, 2, 8), 0, 6000)
serialize("C:\\Users\\hoore\\Documents\\data\\init_ob.data", init_ob)
=#

odr_vec = deserialize("C:\\Users\\hoore\\Documents\\data\\odrs.data")
init_ob = deserialize("C:\\Users\\hoore\\Documents\\data\\init_ob.data")

using ProgressBars: ProgressBar

@time for odr in ProgressBar(odr_vec)
    #if i == 148707 break end
    match_odr!(odr, init_ob)
end

=#
# test codes end
