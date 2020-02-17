mutable struct Account
    amt::Int
    p::Float64
end


mutable struct Book
    cash::Float64;
    sec_dct::Dict{Symbol, Account};

    @inline Book(cash::Float64) = new(cash, Dict{Symbol, Account}())
end


@inline function get_mkt_value(bk::Book)::Float64
    if isempty(bk.sec_dct)
        return bk.cash
    else
        return bk.cash + sum(x->x.amt * x.p, values(bk.sec_dct))
    end
end


@inline function book_fill!(bk::Book, of::OrderFill)::Int
    si = of.rc_odr.side == :buy ? 1 : -1
    bk.cash -= of.p * of.amt * si

    tkr = of.rc_odr.tkr
    if !(tkr in keys(bk.sec_dct))
        bk.sec_dct[tkr] = Account(0, of.p)
    end

    bk.sec_dct[tkr].amt += of.amt * si
end


@inline function mark2mkt!(bk::Book, qt::Dict{Symbol, <:Real})::Float64
    for (tkr, p) in qt
        if tkr in keys(bk.sec_dct)
            bk.sec_dct[tkr].p = p
        end
    end

    return get_mkt_value(bk)
end


# test begin
#=
using Dates
bk = Book(1000.0)
of = OrderFill(ReceivedOdr(:abc, 100, 20, now(), :sell, :public, get_uuid()),
    10, 20.0, now()
)

mark2mkt!(bk, Dict(:abc => 20))
book_fill!(bk, of)
mark2mkt!(bk, Dict(:abc => 30))

mark2mkt!(bk, Dict(:abc => 10))
=#
# test end
