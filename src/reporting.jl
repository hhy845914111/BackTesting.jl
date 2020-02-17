abstract type AbstractReport end


struct SingleReturnReport{T<:Real} <: AbstractReport
    rt_ar::AbstractVector{T};
    rt_total::T;

    @inline function SingleReturnReport{T}(rt_ar::AbstractVector{T}) where {T<:Real}
        new{T}(rt_ar, rt_ar[end]);
    end
end


struct TestReport <: AbstractReport
    _rt
end
