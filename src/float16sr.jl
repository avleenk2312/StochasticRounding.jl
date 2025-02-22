import BFloat16s.BFloat16
"""Float16 + stochastic rounding type."""
primitive type Float16sr <: AbstractFloat 16 end

# basic properties (same as for Float16)
Base.sign_mask(::Type{Float16sr}) = 0x8000
Base.exponent_mask(::Type{Float16sr}) = 0x7c00
Base.significand_mask(::Type{Float16sr}) = 0x03ff
Base.precision(::Type{Float16sr}) = 11

Base.one(::Type{Float16sr}) = reinterpret(Float16sr,0x3c00)
Base.zero(::Type{Float16sr}) = reinterpret(Float16sr,0x0000)
Base.one(::Float16sr) = one(Float16sr)
Base.zero(::Float16sr) = zero(Float16sr)
Base.rand(::Type{Float16sr}) = reinterpret(Float16sr,rand(Float16))
Base.randn(::Type{Float16sr}) = reinterpret(Float16sr,randn(Float16))

Base.typemin(::Type{Float16sr}) = Float16sr(typemin(Float16))
Base.typemax(::Type{Float16sr}) = Float16sr(typemax(Float16))
Base.floatmin(::Type{Float16sr}) = Float16sr(floatmin(Float16))
Base.floatmax(::Type{Float16sr}) = Float16sr(floatmax(Float16))
Base.maxintfloat(::Type{Float16sr}) = Float16sr(maxintfloat(Float16))

Base.typemin(::Float16sr) = typemin(Float16sr)
Base.typemax(::Float16sr) = typemax(Float16sr)
Base.floatmin(::Float16sr) = floatmin(Float16sr)
Base.floatmax(::Float16sr) = floatmax(Float16sr)

Base.eps(::Type{Float16sr}) = Float16sr(eps(Float16))
Base.eps(x::Float16sr) = Float16sr(eps(Float16(x)))

const Inf16sr = reinterpret(Float16sr, Inf16)
const NaN16sr = reinterpret(Float16sr, NaN16)

# basic operations
Base.abs(x::Float16sr) = reinterpret(Float16sr, reinterpret(UInt16, x) & 0x7fff)
Base.isnan(x::Float16sr) = isnan(Float16(x))
Base.isfinite(x::Float16sr) = isfinite(Float16(x))

Base.uinttype(::Type{Float16sr}) = UInt16
Base.nextfloat(x::Float16sr) = Float16sr(nextfloat(Float16(x)))
Base.prevfloat(x::Float16sr) = Float16sr(prevfloat(Float16(x)))

Base.:(-)(x::Float16sr) = reinterpret(Float16sr, reinterpret(UInt16, x) ⊻ Base.sign_mask(Float16sr))

# conversions via deterministic round-to-nearest
Base.Float16(x::Float16sr) = reinterpret(Float16,x)
Float16sr(x::Float16) = reinterpret(Float16sr,x)
Float16sr(x::Float32) = Float16sr(Float16(x))
Float16sr(x::Float64) = Float16sr(Float32(x))
Base.Float32(x::Float16sr) = Float32(Float16(x))
Base.Float64(x::Float16sr) = Float64(Float16(x))

#irrationals
Float16sr(x::Irrational) = reinterpret(Float16sr,Float16(x))

# converting to and from BFloat16
Float16sr(x::BFloat16) = Float16sr(Float32(x))
BFloat16(x::Float16sr) = BFloat16(Float16(x))

Float16sr(x::Integer) = Float16sr(Float32(x))
(::Type{T})(x::Float16sr) where {T<:Integer} = T(Float32(x))

"""
    rand_subnormal(rbits::UInt32) -> Float32

Create a random perturbation for the Float16 subnormals for
stochastic rounding of Float32 -> Float16.
This function samples uniformly from [-2.980232f-8,2.9802319f-8].
This function is algorithmically similar to randfloat from RandomNumbers.jl"""
function rand_subnormal(rbits::UInt32)
    lz = leading_zeros(rbits)   # count leading zeros for correct probabilities of exponent
    e = ((101 - lz) % UInt32) << 23
    e |= (rbits << 31)          # use last bit for sign
    
    # combine exponent with random mantissa
    return reinterpret(Float32,e | (rbits & 0x007f_ffff))
end

const eps_F16 = prevfloat(Float32(nextfloat(zero(Float16))),1)
const floatmin_F16 = Float32(floatmin(Float16))
const oneF32 = reinterpret(Int32,one(Float32))

# # old version 
# function rand_subnormal(rbits::UInt32)
#     return eps_F16*(reinterpret(Float32,oneF32 | (rbits >> 9))-1.5f0)
# end

"""
    Float16_stochastic_round(x::Float32) -> Float16sr

Stochastically round `x` to Float16 with distance-proportional probabilities."""
function Float16_stochastic_round(x::Float32)
    rbits = rand(Xor128[],UInt32)   # create random bits

    # subnormals are rounded with float-arithmetic for uniform stoch perturbation
    abs(x) < floatmin_F16 && return Float16sr(x+rand_subnormal(rbits))
    
    # normals are stochastically rounded with integer arithmetic
    ui = reinterpret(UInt32,x)
    mask = 0x0000_1fff          # only mantissa bit 11-23 (the non-Float16 ones)
    ui += (rbits & mask)        # add perturbation in [0,u)
    ui &= ~mask                 # round to zero

    # via conversion to Float16 to adjust exponent bits
    return Float16sr(reinterpret(Float32,ui))
end

"""
    Float16_chance_roundup(x::Float32)

Chance that x::Float32 is round up when converted to Float16sr."""
function Float16_chance_roundup(x::Float32)
    xround = Float32(Float16(x))
    xround == x && return zero(Float32)
    xround_down, xround_up = xround < x ? (xround,Float32(nextfloat(Float16(xround)))) :
        (Float32(prevfloat(Float16(xround))),xround)
    
    return (x-xround_down)/(xround_up-xround_down)
end

# Promotion, always to the deterministic format that contains both
Base.promote_rule(::Type{Float16}, ::Type{Float16sr}) = Float16
Base.promote_rule(::Type{Float32}, ::Type{Float16sr}) = Float32
Base.promote_rule(::Type{Float64}, ::Type{Float16sr}) = Float64

for t in (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128)
    @eval Base.promote_rule(::Type{Float16sr}, ::Type{$t}) = Float16sr
end

# Rounding
Base.round(x::Float16sr, r::RoundingMode{:ToZero}) = Float16sr(round(Float32(x), r))
Base.round(x::Float16sr, r::RoundingMode{:Down}) = Float16sr(round(Float32(x), r))
Base.round(x::Float16sr, r::RoundingMode{:Up}) = Float16sr(round(Float32(x), r))
Base.round(x::Float16sr, r::RoundingMode{:Nearest}) = Float16sr(round(Float32(x), r))

# Comparison
for op in (:(==), :<, :<=, :isless)
    @eval Base.$op(a::Float16sr, b::Float16sr) = ($op)(Float16(a), Float16(b))
end

# Arithmetic
for f in (:+, :-, :*, :/, :^, :mod)
    @eval Base.$f(x::Float16sr, y::Float16sr) = Float16_stochastic_round($(f)(Float32(x), Float32(y)))
end

for func in (:sin,:cos,:tan,:asin,:acos,:atan,:sinh,:cosh,:tanh,:asinh,:acosh,
             :atanh,:exp,:exp2,:exp10,:expm1,:log,:log2,:log10,:sqrt,:cbrt,:log1p)
    @eval begin
        Base.$func(a::Float16sr) = Float16_stochastic_round($func(Float32(a)))
    end
end

for func in (:atan,:hypot)
    @eval begin
        Base.$func(a::Float16sr,b::Float16sr) = Float16_stochastic_round($func(Float32(a),Float32(b)))
    end
end

#sincos function
function Base.sincos(x::Float16sr)
    s,c = sincos(Float32(x))
    return (Float16_stochastic_round(s),Float16_stochastic_round(c))
end

# array generators
Base.rand(::Type{Float16sr},dims::Integer...) = reinterpret.(Float16sr,rand(Float16,dims...))
Base.randn(::Type{Float16sr},dims::Integer...) = reinterpret.(Float16sr,randn(Float16,dims...))
Base.zeros(::Type{Float16sr},dims::Integer...) = reinterpret.(Float16sr,zeros(Float16,dims...))
Base.ones(::Type{Float16sr},dims::Integer...) = reinterpret.(Float16sr,ones(Float16,dims...))

Base.show(io::IO, x::Float16sr) = show(io,Float16(x))
Base.bitstring(x::Float16sr) = bitstring(reinterpret(UInt16,x))

function Base.bitstring(x::Float16sr,mode::Symbol)
    if mode == :split	# split into sign, exponent, signficand
        s = bitstring(x)
        return "$(s[1]) $(s[2:6]) $(s[7:end])"
    else
        return bitstring(x)
    end
end

# BIGFLOAT
Float16sr(x::BigFloat) = Float16sr(Float64(x))
Base.decompose(x::Float16sr) = Base.decompose(Float16(x))
