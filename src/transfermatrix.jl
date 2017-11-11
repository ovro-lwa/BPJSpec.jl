# Copyright (c) 2015-2017 Michael Eastwood
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

abstract TransferMatrix

struct FileBackedTransferMatrix <: TransferMatrix
    path :: String
    metadata_sph :: SphericalHarmonicMetadata
    metadata_int :: InterferometerMetadata
    function FileBackedTransferMatrix(path,
                                      metadata_sph::SphericalHarmonicMetadata,
                                      metadata_int::InterferometerMetadata)
        isdir(path) || mkdir(path)
        save(joinpath(path, "METADATA.jld"),
             "spherical-harmonics", metadata_sph,
             "interferometer", metadata_int)
        new(path, metadata_sph, metadata_int)
    end
end

function FileBackedTransferMatrix(path)
    metadata_sph, metadata_int = load(joinpath(path, "METADATA.jld"),
                                      "spherical-harmonics", "interferometer")
    FileBackedTransferMatrix(path, metadata_sph, metadata_int)
end

function compute!(transfermatrix::FileBackedTransferMatrix)
    rhat = unit_vectors(nside)
end

function unit_vectors(nside)
    [pix2vec_ring(nside, pix) for pix = 1:nside2npix(nside)]
end

#function baseline_vectors(metadata)
#    uvw = zeros(3, Nbase(metadata))
#    for α = 1:Nbase(metadata)
#        antenna1 = metadata.antennas[metadata.baselines[α].antenna1]
#        antenna2 = metadata.antennas[metadata.baselines[α].antenna2]
#        uvw[1, α] = antenna1.position.x - antenna2.position.x
#        vvw[2, α] = antenna1.position.y - antenna2.position.y
#        wvw[3, α] = antenna1.position.z - antenna2.position.z
#    end
#    frame = TTCal.reference_frame(metadata)
#    phase_center = measure(frame, metadata.phase_center, dir"ITRF")
#    uvw, phase_center
#end





#function generate_transfermatrix!(transfermatrix, meta, variables)
#    for ν in transfermatrix.frequencies
#        beam = beam_map(meta, ν)
#        generate_transfermatrix_onechannel!(transfermatrix, meta, beam, variables, ν)
#    end
#end
#
#function generate_transfermatrix!(transfermatrix, meta, beam, variables)
#    for ν in transfermatrix.frequencies
#        generate_transfermatrix_onechannel!(transfermatrix, meta, beam, variables, ν)
#    end
#end
#
#function generate_transfermatrix_onechannel!(transfermatrix, meta, beam, variables, ν)
#    lmax = transfermatrix.lmax
#    mmax = transfermatrix.mmax
#    # Memory map all the blocks on the master process to avoid having to
#    # open/close the files multiple times and to avoid having to read the
#    # entire matrix at once.
#    info("Running new version!")
#    info("Memory mapping files")
#    blocks = IOStream[]
#    #blocks = Matrix{Complex128}[]
#    for m = 0:mmax
#        directory = directory_name(m, ν, mmax+1)
#        directory = joinpath(transfermatrix.path, directory)
#        isdir(directory) || mkdir(directory)
#        filename = block_filename(m, ν)
#        block = open(joinpath(directory, filename), "w")
#        # Write the size of the matrix block to the start of
#        # the file because in general we don't know how many
#        # rows will be in each block of the matrix.
#        #
#        # Also note that we are storing the transpose of each
#        # block in order to make all the disk writes sequential.
#        sz = (lmax-m+1, two(m)*Nbase(meta))
#        write(block, sz[1], sz[2])
#        push!(blocks, block)
#        #open(joinpath(directory, filename), "w+") do file
#        #    # note that we store the transpose of the transfer matrix blocks to make
#        #    # all the disk writes sequential
#        #    sz = (lmax-m+1, two(m)*Nbase(meta))
#        #    write(file, sz[1], sz[2])
#        #    block = Mmap.mmap(file, Matrix{Complex128}, sz)
#        #    push!(blocks, block)
#        #end
#        #open(joinpath(directory, filename), "r+") do file
#        #    sz1 = read(file, Int)
#        #    sz2 = read(file, Int)
#        #    sz = (sz1, sz2)
#        #    block = Mmap.mmap(file, Matrix{Complex128}, sz)
#        #    push!(blocks, block)
#        #end
#    end
#    info("Beginning the computation")
#    idx = 1
#    #idx = 1500
#    nextidx() = (myidx = idx; idx += 1; myidx)
#    p = Progress(Nbase(meta) - idx + 1, "Progress: ")
#    l = ReentrantLock()
#    increment_progress() = (lock(l); next!(p); unlock(l))
#    @sync for worker in workers()
#        @async begin
#            input = RemoteChannel()
#            output_realfringe = RemoteChannel()
#            output_imagfringe = RemoteChannel()
#            remotecall(transfermatrix_worker_loop, worker,
#                       input, output_realfringe, output_imagfringe, beam, variables, ν)
#            while true
#                α = nextidx()
#                α ≤ Nbase(meta) || break
#                put!(input, α)
#                realfringe = take!(output_realfringe)
#                imagfringe = take!(output_imagfringe)
#                pack!(blocks, realfringe, imagfringe, lmax, mmax, α)
#                increment_progress()
#            end
#        end
#    end
#    for block in blocks
#        close(block)
#    end
#end
#
#function transfermatrix_worker_loop(input, output_realfringe, output_imagfringe, beam, variables, ν)
#    while true
#        α = take!(input)
#        realfringe, imagfringe = fringes(beam, variables, ν, α)
#        put!(output_realfringe, realfringe)
#        put!(output_imagfringe, imagfringe)
#    end
#end
#
#"""
#    planewave(u, v, w, x, y, z, phase_center)
#
#Compute the fringe pattern over a Healpix image.
#
#```math
#exp(2 \pi i (ux+vy+wz)
#```
#"""
#function planewave(u, v, w, x, y, z, phase_center)
#    realmap = HealpixMap(Float64, nside(x))
#    imagmap = HealpixMap(Float64, nside(x))
#    for idx = 1:length(realmap)
#        δx = x[idx] - phase_center.x
#        δy = y[idx] - phase_center.y
#        δz = z[idx] - phase_center.z
#        ϕ = 2π*(u*δx + v*δy + w*δz)
#        realmap[idx] = cos(ϕ)
#        imagmap[idx] = sin(ϕ)
#    end
#    realmap, imagmap
#end
#
#"""
#    fringes(beam, variables, ν, α)
#
#Generate the spherical harmonic expansion of the fringe pattern on the sky.
#
#Note that because the Healpix library assumes you are asking for the coefficients
#of a real field, there must be one set of coefficients for the real part of
#the fringe pattern and one set of coefficients for the imaginary part of the
#fringe pattern.
#"""
#function fringes(beam, variables, ν, α)
#    λ = c / ν
#    u = variables.u[α] / λ
#    v = variables.v[α] / λ
#    w = variables.w[α] / λ
#    realmap, imagmap = planewave(u, v, w, variables.x, variables.y, variables.z, variables.phase_center)
#    realfringe = map2alm(beam .* realmap, variables.lmax, variables.mmax, iterations=2)
#    imagfringe = map2alm(beam .* imagmap, variables.lmax, variables.mmax, iterations=2)
#    realfringe, imagfringe
#end
#
#"""
#    pack!(blocks, realfringe, imagfringe, lmax, mmax, α)
#
#Having calculated the spherical harmonic expansion of the fringe pattern,
#pack those numbers into the transfer matrix.
#"""
#function pack!(blocks, realfringe, imagfringe, lmax, mmax, α)
#    # Note that all the conjugations in this function come about because
#    # Shaw et al. 2014, 2015 expand the fringe pattern in terms of the
#    # spherical harmonic conjugates while we've expanded the fringe pattern
#    # in terms of the spherical harmonics.
#    #for l = 0:lmax
#    #    blocks[1][l+1,α] = conj(realfringe[l,0]) + 1im*conj(imagfringe[l,0])
#    #end
#    #for m = 1:mmax
#    #    block = blocks[m+1]
#    #    α1 = 2α-1 # positive m
#    #    for l = m:lmax
#    #        block[l-m+1,α1] = conj(realfringe[l,m]) + 1im*conj(imagfringe[l,m])
#    #    end
#    #    α2 = 2α-0 # negative m
#    #    for l = m:lmax
#    #        block[l-m+1,α2] = conj(realfringe[l,m]) - 1im*conj(imagfringe[l,m])
#    #    end
#    #end
#    offset = 2sizeof(Int) + (α-1)*(lmax+1)*sizeof(Complex128)
#    output = Complex128[conj(realfringe[l,0]) + 1im*conj(imagfringe[l,0]) for l = 0:lmax]
#    seek(blocks[1], offset)
#    write(blocks[1], output)
#    for m = 1:mmax
#        offset = 2sizeof(Int) + 2*(α-1)*(lmax-m+1)*sizeof(Complex128)
#        output1 = Complex128[conj(realfringe[l,m]) + 1im*conj(imagfringe[l,m]) for l = m:lmax] # positive m
#        output2 = Complex128[conj(realfringe[l,m]) - 1im*conj(imagfringe[l,m]) for l = m:lmax] # negative m
#        seek(blocks[m+1], offset)
#        write(blocks[m+1], output1, output2)
#    end
#end
#
#function setindex!(transfermatrix::TransferMatrix, block, m, channel)
#    ν = transfermatrix.frequencies[channel]
#    directory = directory_name(m, ν, transfermatrix.mmax+1)
#    filename = block_filename(m, ν)
#    open(joinpath(transfermatrix.path, directory, filename), "w") do file
#        write(file, size(block, 2), size(block, 1), block.')
#    end
#    block
#end
#
#function getindex(transfermatrix::TransferMatrix, m, channel)
#    local block
#    ν = transfermatrix.frequencies[channel]
#    directory = directory_name(m, ν, transfermatrix.mmax+1)
#    filename = block_filename(m, ν)
#    open(joinpath(transfermatrix.path, directory, filename), "r") do file
#        sz = tuple(read(file, Int, 2)...)
#        block = read(file, Complex128, sz)
#    end
#    block.'
#end
#
##=
#doc"""
#    preserve_singular_values(B::TransferMatrix)
#
#Construct a matrix that projects the $m$-modes onto a lower dimensional
#space while preserving all the singular values of the transfer matrix.
#
#Multiplying by this matrix will compress the data, make the transfer
#matrix square, and leave the information about the sky untouched.
#"""
#function preserve_singular_values(B::TransferMatrix)
#    N = length(B.blocks)
#    blocks = Array{MatrixBlock}(N)
#    for i = 1:N
#        U,σ,V = svd(B.blocks[i])
#        blocks[i] = MatrixBlock(U')
#    end
#    Blocks(blocks)
#end
#=#

