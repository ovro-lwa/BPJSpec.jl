using BPJSpec
using Base.Test

srand(123)

# Verify that the visibilities -> m-modes -> visibilities
# round-trip works.
let Nant = 3, mmax = 5
    Nbase = div(Nant*(Nant-1),2)
    data = zeros(Complex128,Nbase,2mmax+1)
    rand!(data)
    mmodes = MModes(data,mmax=mmax)
    data′ = visibilities(mmodes)
    @test_approx_eq data data′
end

