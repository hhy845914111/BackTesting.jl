using Dates: DateTime
using DataStructures: OrderedDict, Queue


struct Order
    tkr::Symbol
    amt::Int
    p::Int
    side::Symbol
    action::Symbol
    dt::DateTime
    usr::Symbol

    uuid::Int128
end


mutable struct ReceivedOdr
    tkr::Symbol
    amt::Int
    p::Int
    dt::DateTime
    side::Symbol
    usr::Symbol

    uuid::Int128
end


struct OrderFill
    rc_odr::ReceivedOdr
    amt::Int
    p::Float64
    dt::DateTime
end


let odr_cnt::Int128 = 0
    global @inline get_uuid() = odr_cnt += 1
end


mutable struct OrderBook
    tkr::Symbol
    b_ld::OrderedDict{Int, Queue{ReceivedOdr}}
    a_ld::OrderedDict{Int, Queue{ReceivedOdr}}
    b_top::Int
    a_top::Int

    p_l::Int
    p_h::Int


    @inline function OrderBook(tkr::Symbol,
        p_l::Int, p_h::Int)

        tpl = p_l : 1 : p_h;
        tld1 = OrderedDict{Int, Queue{ReceivedOdr}}(
            Pair.(tpl, [Queue{ReceivedOdr}() for _ in tpl])
        );
        tld2 = OrderedDict{Int, Queue{ReceivedOdr}}(
            Pair.(tpl, [Queue{ReceivedOdr}() for _ in tpl])
        );
        new(tkr, tld1, tld2, p_l - 1, p_h + 1, p_l, p_h)
    end
end


@inline function find_next_level(ld::OrderedDict{Int, Queue{ReceivedOdr}},
    itr::StepRange{Int, Int})::Int

    for i = itr
        if !isempty(ld[i])
            return i
        end
    end

    return itr.stop + itr.step
end


function gen_odrs(ob::OrderBook, nb::OrderBook,
    whos::Symbol)::AbstractVector{Order}

    o_v = Vector{Order}()
    tkr = ob.tkr

    for (o_ld, n_ld) in ((ob.b_ld, nb.b_ld), (ob.a_ld, nb.a_ld))
        @inbounds for p in keys(o_ld)
            s_o, s_n = Set(o_ld[p]), Set(n_ld[p])

            submit_rc_odrs = setdiff(s_n, s_o)
            for rc_odr in submit_rc_odrs
                push!(o_v, Order(tkr, rc_odr.amt, rc_odr.p, :buy, :submit,
                    rc_odr.dt, whos, get_uuid())
                )
            end

            cancel_rc_odrs = setdiff(s_o, s_n)
            for rc_odr in cancel_rc_odrs
                push!(o_v, Order(tkr, rc_odr.amt, rc_odr.p, :buy, :cancel,
                    rc_odr.dt, whos, get_uuid())
                )
            end
        end
    end

    return o_v
end


@inline function show(ob::OrderBook, lv_ct::Integer=5)::Nothing
    if ob.a_top > ob.p_h || ob.b_top < ob.p_l
        return
    end

    p_u, p_l = ob.a_top + lv_ct, ob.b_top - lv_ct
    ps = p_u : -1 : p_l

    for p = p_u : -1 : p_l
        if !isempty(ob.b_ld[p])
            bv = sum(x->x.amt, ob.b_ld[p])
        else
            bv = 0
        end
        if !isempty(ob.a_ld[p])
            av = sum(x->x.amt, ob.a_ld[p])
        else
            av = 0
        end

        print(p, " $bv $av\n")
    end
end
