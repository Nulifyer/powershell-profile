FROM docker.io/library/alpine:3

RUN apk update && apk upgrade && apk add --no-cache \
    # Archive & Compression
    bzip2 \
    gzip \
    tar \
    unzip \
    xz \
    zip \
    # Development
    build-base \
    git \
    python3 \
    # Editors
    nano \
    vim \
    # File Search & Text Processing
    findutils \
    fzf \
    gawk \
    grep \
    ripgrep \
    sed \
    # Network
    ca-certificates \
    curl \
    bind-tools \
    iproute2 \
    iputils-ping \
    nmap \
    openssh-client \
    rsync \
    wget \
    # Shell
    bash \
    sudo \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    # System Monitoring & Utilities
    bat \
    eza \
    fastfetch \
    htop \
    iotop \
    jq \
    lsof \
    procps

# Install Go from official source
RUN curl -fsSL https://go.dev/dl/go1.26.0.linux-amd64.tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:$PATH"

# Install .NET SDKs (8, 9, 10)
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet && \
    /tmp/dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet && \
    /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet && \
    rm /tmp/dotnet-install.sh
ENV DOTNET_ROOT="/usr/share/dotnet"
ENV PATH="$DOTNET_ROOT:$PATH"

ENV DENO_INSTALL="/deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"
RUN curl -fsSL https://deno.land/x/install/install.sh | sh

# Install oh-my-posh
RUN curl -fsSL https://ohmyposh.dev/install.sh | sh -s
ENV PATH="/root/.local/bin:$PATH"

# Copy theme file
COPY catppuccin_mocha.omp.json /etc/oh-my-posh/catppuccin_mocha.omp.json

# Configure zsh with completions and oh-my-posh
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.zshrc && \
    echo 'export USERNAME=$(whoami)' >> /root/.zshrc && \
    echo 'export HOSTNAME=$(hostname)' >> /root/.zshrc && \
    echo 'autoload -Uz compinit && compinit' >> /root/.zshrc && \
    echo 'zstyle ":completion:*" matcher-list "m:{a-zA-Z}={A-Za-z}"' >> /root/.zshrc && \
    echo 'zstyle ":completion:*" menu select' >> /root/.zshrc && \
    echo 'source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /root/.zshrc && \
    echo 'source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc && \
    echo 'eval "$(oh-my-posh init zsh --config /etc/oh-my-posh/catppuccin_mocha.omp.json)"' >> /root/.zshrc && \
    echo 'alias ls="eza --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias ll="eza -l --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias la="eza -la --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias tree="eza --tree --icons"' >> /root/.zshrc && \
    echo 'alias cat="bat --paging=never"' >> /root/.zshrc

# Create alpine user with passwordless sudo
RUN adduser -D -s /bin/zsh alpine && \
    echo 'alpine ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/alpine && \
    cp /root/.zshrc /home/alpine/.zshrc && \
    mkdir -p /home/alpine/.local/bin && \
    cp -r /root/.local/bin/* /home/alpine/.local/bin/ && \
    chown -R alpine:alpine /home/alpine

USER alpine
CMD ["/bin/zsh"]
