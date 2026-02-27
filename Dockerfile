FROM golang:1.18.10-alpine3.17

# Install system dependencies for OCaml and opam
RUN apk add --no-cache \
    bash \
    build-base \
    bzip2 \
    curl \
    gcc \
    git \
    m4 \
    make \
    musl-dev \
    ncurses \
    ncurses-dev \
    ocaml \
    opam \
    patch \
    rsync \
    sudo \
    tar \
    unzip \
    wget

# Create the NeoGoDDaR user and home directory
RUN addgroup -S neogoddar \
    && adduser -S -G neogoddar -h /home/NeoGoDDaR -s /bin/bash NeoGoDDaR \
    && mkdir -p /home/NeoGoDDaR \
    && chown -R NeoGoDDaR:neogoddar /home/NeoGoDDaR

# Allow NeoGoDDaR to use sudo without a password
RUN echo 'NeoGoDDaR ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to NeoGoDDaR — all remaining work is done as this user
USER NeoGoDDaR
WORKDIR /home/NeoGoDDaR

# Initialise opam for NeoGoDDaR, create switch, and install dune and menhir
RUN opam init --disable-sandboxing --bare -y \
    && opam switch create default --formula='"ocaml-system"' \
    && opam switch set default \
    && opam install -y dune menhir \
    && echo 'eval $(opam env)' >> /home/NeoGoDDaR/.bashrc \
    && echo 'eval $(opam env)' >> /home/NeoGoDDaR/.profile

# Bake the opam environment into the image PATH
ENV OPAM_SWITCH_PREFIX=/home/NeoGoDDaR/.opam/default
ENV CAML_LD_LIBRARY_PATH=/home/NeoGoDDaR/.opam/default/lib/stublibs:/home/NeoGoDDaR/.opam/default/lib/ocaml/stublibs:/home/NeoGoDDaR/.opam/default/lib/ocaml
ENV OCAML_TOPLEVEL_PATH=/home/NeoGoDDaR/.opam/default/lib/toplevel
ENV MANPATH=/home/NeoGoDDaR/.opam/default/man
ENV PATH=/home/NeoGoDDaR/.opam/default/bin:$PATH

# Step 1: Clone and install gospal (migoinfer)
# migoinfer must be installed first as NeoGoDDaR depends on it at runtime
RUN git clone https://github.com/GustavoFeio/gospal.git /home/NeoGoDDaR/gospal

RUN cd /home/NeoGoDDaR/gospal/cmd/migoinfer \
    && go install

# Step 2: Clone and build NeoGoDDaR
RUN git clone https://github.com/GustavoFeio/NeoGoDDaR.git /home/NeoGoDDaR/NeoGoDDaR

RUN cd /home/NeoGoDDaR/NeoGoDDaR \
    && dune build

# Step 3: Install the fixer (Go tool for automatic patching of Go source code)
RUN cd /home/NeoGoDDaR/NeoGoDDaR/fixer \
    && go install GoDDaR_fixer

# Ensure Go-installed binaries (migoinfer, GoDDaR_fixer) are on PATH
ENV PATH=/home/NeoGoDDaR/go/bin:$PATH

# Step 4: Copy the entrypoint script and make it executable
COPY --chown=NeoGoDDaR:neogoddar entrypoint.sh /home/NeoGoDDaR/entrypoint.sh
RUN chmod +x /home/NeoGoDDaR/entrypoint.sh

# Create a workspace directory for users to mount their own files
RUN mkdir -p /home/NeoGoDDaR/workspace

WORKDIR /home/NeoGoDDaR/NeoGoDDaR

ENTRYPOINT ["/home/NeoGoDDaR/entrypoint.sh"]
