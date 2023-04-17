FROM gradle:7-jdk17

ARG UBUNTU_MIRROR=archive.ubuntu.com
ARG GHIDRA_RELEASE_TAG=Ghidra_10.2.3_build
ARG GHIDRA_VERSION=ghidra_10.2.3_PUBLIC
ARG GHIDRA_BUILD=${GHIDRA_VERSION}_20230208
ARG Z3_VERSION="4.12.1"

# Non-interactive installation requirements
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/ghidra:/opt/ghidra/support:${PATH}"
ENV GHIDRA_INSTALL_DIR="/opt/ghidra"

# Set installation options
RUN echo 'debconf debconf/frontend select Noninteractive' > /debconf-seed.txt && \
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' >> /debconf-seed.txt && \
    echo 'locales locales/default_environment_locale select en_US.UTF-8' >> /debconf-seed.txt && \
    debconf-set-selections /debconf-seed.txt

# Use custom mirror
RUN sed -i "s/archive.ubuntu.com/${UBUNTU_MIRROR}/g" /etc/apt/sources.list

RUN apt-get update -qq && apt-get install -y \
        wget unzip make cmake build-essential

# Ghidra installation

RUN wget https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_RELEASE_TAG}/${GHIDRA_BUILD}.zip && \
    unzip -d ghidra ${GHIDRA_BUILD}.zip && \
    rm ${GHIDRA_BUILD}.zip && \
    mv ghidra/ghidra_* /opt/ghidra

RUN mkdir /opt/z3 && cd /opt/z3 \
    && wget -qO- https://github.com/Z3Prover/z3/archive/z3-${Z3_VERSION}.tar.gz | tar xz --strip-components=1 \
    && mkdir build && cd build && cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DZ3_BUILD_JAVA_BINDINGS=ON \
        -DZ3_INSTALL_JAVA_BINDINGS=ON .. \
        && make -j8 && make install \
    && cp /opt/z3/build/*.so /lib64

COPY ghidra_scripts /data/workspace/BinAbsInspector/ghidra_scripts
COPY lib /data/workspace/BinAbsInspector/lib
COPY src /data/workspace/BinAbsInspector/src
COPY build.gradle extension.properties Module.manifest /data/workspace/BinAbsInspector/

WORKDIR /data/workspace/BinAbsInspector

# Build extension
RUN gradle compileJava --warning-mode all \
        && gradle buildExtension --warning-mode all

# Install extension
RUN cp dist/*.zip "${GHIDRA_INSTALL_DIR}/Ghidra/Extensions" && \
        cd "${GHIDRA_INSTALL_DIR}/Ghidra/Extensions" && unzip *.zip

# Provide an easy way to run the plugin
WORKDIR /data/workspace
ENTRYPOINT ["analyzeHeadless", ".", "tmp", "-deleteProject", "-overwrite", "-postScript", "BinAbsInspector.java"]
