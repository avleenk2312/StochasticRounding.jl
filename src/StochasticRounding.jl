module StochasticRounding

    export BFloat16sr,BFloat16_stochastic_round,        # BFloat16 + SR
        BFloat16_chance_roundup,NaNB16sr,InfB16sr,
        Float16sr,Float16_stochastic_round,             # Float16 + SR
        Float16_chance_roundup,NaN16sr,Inf16sr,
        Float32sr,Float32_stochastic_round,             # Float32 + SR
        Float32_chance_roundup,NaN32sr,Inf32sr,
        Float64sr,Float64_stochastic_round,             # Float64 + SR
        Float64_chance_roundup,
        NaNsr,Infsr

    # use BFloat16 from BFloat16s.jl
    import BFloat16s: BFloat16

    # faster random number generator
    import RandomNumbers.Xorshifts.Xoroshiro128Plus
    const Xor128 = Ref{Xoroshiro128Plus}(Xoroshiro128Plus())

    import DoubleFloats: DoubleFloats, Double64

    """Reseed the PRNG randomly by recalling."""
    function __init__()
        Xor128[] = Xoroshiro128Plus()
    end

    """Seed the PRNG with any integer >0."""
    function seed(i::Integer)
        Xor128[] = Xoroshiro128Plus(UInt64(i))
        return nothing
    end

    include("bfloat16sr.jl")
    include("float16sr.jl")
    include("float32sr.jl")
    include("float64sr.jl")

    include("general.jl")
    include("promotion.jl")
    include("conversions.jl")
end
