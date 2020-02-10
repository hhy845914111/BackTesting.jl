using DataStructures

include("matching.jl")


abstract type AbstractAccount end;


struct Account{T<:AbstractFloat} <: AbstractAccount
    cash::T;

    securities::Dict{AbstractString, Int};
    transact_hist::Stack{OrderFill};

    value_hist::Vector{AbstractFloat};

    @inline function Account{T}(cash_::T) where {T<:AbstractFloat}
        new{T}(cash_, Dict{AbstractString, Int}(), Stack{OrderFill}());
    end
end;


function book_trades!(filled_order_tpl::Tuple{OrderFill})

end
