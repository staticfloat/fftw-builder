#!/usr/bin/env julia
using BinDeps2

# Helper function to return the name of the libfftw library given the platform
function libfftw_name(platform::Symbol)
	if platform == :mac64
		return "libfftw3_threads.dylib"
	end
	if platform == :win64
		return "libfftw3-3.dll"
	end
	return "libfftw3_threads.so"
end


for platform in BinDeps2.supported_platforms()
	# Skip :mac64 for now, because the assembler barfs
	if platform == :mac64
		continue
	end
    BinDeps2.temp_prefix() do prefix
        # First, build libfftw
        libfftw = BinDeps2.LibraryResult(joinpath(BinDeps2.libdir(prefix), libfftw_name(platform)))
        #fooifier = BinDeps2.FileResult(joinpath(BinDeps2.bindir(prefix), "fooifier"))
        steps = [`make clean`, `make`]
        dep = BinDeps2.Dependency("libfftw", BinDeps2.BuildResult[], steps, platform, prefix)

        BinDeps2.build(dep; verbose=true, force=true)

        # Next, package it up as a .tar.gz file
        rm("./libfftw_$(platform).tar.gz"; force=true)
        tarball_path = BinDeps2.package(prefix, "./libfftw", platform=platform)
        info("Built and saved at $(tarball_path)")
    end
end
