FROM debian:stretch-20181226

# Install tools and dependencies.
RUN apt-get update && \
    apt-get install -y \
        apt-transport-https \
        dirmngr \
        gnupg \
        ca-certificates \
        make \
        git \
        gcc \
        g++ \
        autoconf \
        libtool \
        automake \
        cmake \
        gettext \
        python \
        libunwind8 \
        icu-devtools \
	linux-perf

# Download and install the .NET Core SDK.
WORKDIR /dotnet
RUN curl -OL https://download.visualstudio.microsoft.com/download/pr/7e4b403c-34b3-4b3e-807c-d064a7857fe8/95c738f08e163f27867e38c602a433a1/dotnet-sdk-3.0.100-preview5-011568-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-3.0.100-preview5-011568-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/brianrob/aspnetcore && \
    cd aspnetcore && \
    git checkout techempower_net5

# Build the app.
ENV BenchmarksTargetFramework netcoreapp3.0
ENV MicrosoftAspNetCoreAppPackageVersion 3.0.0-preview5-19227-01
ENV MicrosoftNETCoreAppPackageVersion 3.0.0-preview5-27626-15
WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks
RUN dotnet publish -c Release -f netcoreapp3.0 --self-contained -r linux-x64

# Restore the mono binaries.
ENV MONO_PKG_VERSION 6.3.0.621
WORKDIR /src
RUN git clone https://github.com/brianrob/tests && \
    cd tests/managed/restore_net5 && \
    dotnet restore 


# Build mono from source with llvm support; patch system wide .Net
RUN git clone --recurse-submodules -j8 https://github.com/mono/mono.git

WORKDIR /src/mono
RUN ./autogen.sh && \
    make get-monolite-latest && \
    ./autogen.sh --enable-llvm --with-core=only && \
    make -j 4 && \
    cd netcore && \
    make -j 4 && \
    cp /src/mono/mono/mini/.libs/libmonosgen-2.0.so /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish/libcoreclr.so && \
    cp /src/mono/netcore/System.Private.CoreLib/bin/x64/System.Private.CoreLib.dll  /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish/

WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish

#Build Microbenchmarks

WORKDIR /src
RUN git clone https://github.com/dotnet/performance.git

# WORKDIR /src/performance/src/benchmarks/micro
# RUN /src/mono/.dotnet/dotnet build -f netcoreapp5.0 -c release MicroBenchmarks.sln

ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --llvm --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["/bin/bash"]
