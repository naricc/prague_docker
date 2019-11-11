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
        icu-devtools

# Download and install the .NET Core SDK.
WORKDIR /dotnet
RUN curl -OL https://dotnetcli.azureedge.net/dotnet/Sdk/5.0.100-alpha1-014854/dotnet-sdk-5.0.100-alpha1-014854-linux-x64.tar.gz && \
   tar -xzvf dotnet-sdk-5.0.100-alpha1-014854-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet


ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/aspnetcore && \
   cd aspnetcore && \
   git checkout 61179f3da2d389f6d6375a1443b6971d88d2b7f8


# Build the app.
ENV BenchmarksTargetFramework netcoreapp5.0
ENV MicrosoftAspNetCoreAppPackageVersion 5.0.0-alpha1.19470.6
ENV MicrosoftNETCoreAppPackageVersion 5.0.0-alpha1.19507.3
WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks
RUN dotnet build -c Release -f netcoreapp5.0 -r linux-x64

# Build mono from source with llvm support; patch system wide .Net
RUN git clone --recurse-submodules -j8 https://github.com/mono/mono.git

WORKDIR /src/mono
RUN ./autogen.sh && \
    make get-monolite-latest && \
    ./autogen.sh --enable-llvm --with-core=only && \
    make -j 4 && \
    cd netcore && \
    make runtime && \
    make bcl && \
    make patch-local-dotnet
   

WORKDIR /src

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --llvm --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["/bin/bash"]
