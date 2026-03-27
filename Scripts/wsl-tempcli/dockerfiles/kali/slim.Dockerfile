FROM docker.io/kalilinux/kali-rolling:latest

# ── System packages ────────────────────────────────────────────────────────────
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    # Archive & Compression
    bzip2 gzip tar unzip xz-utils zip \
    # Editors
    nano vim \
    # File Search & Text Processing
    findutils fzf gawk grep ripgrep sed \
    # Network (essentials)
    ca-certificates curl openssh-client rsync wget \
    # Shell
    sudo zsh zsh-autosuggestions zsh-syntax-highlighting \
    # System Monitoring & Utilities
    bat eza fastfetch htop jq lsof procps \
    # Version Control
    git \
    && rm -rf /var/lib/apt/lists/*

# ── Shell environment ──────────────────────────────────────────────────────────
ENV RUNTIME_SHELL=/bin/zsh

RUN curl -fsSL https://ohmyposh.dev/install.sh | sh -s
ENV PATH="/root/.local/bin:$PATH"

COPY catppuccin_mocha.omp.json /etc/oh-my-posh/catppuccin_mocha.omp.json

RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.zshrc && \
    echo 'export USERNAME=$(whoami)' >> /root/.zshrc && \
    echo 'export HOSTNAME=$(hostname)' >> /root/.zshrc && \
    echo 'autoload -Uz compinit && compinit' >> /root/.zshrc && \
    echo 'zstyle ":completion:*" matcher-list "m:{a-zA-Z}={A-Za-z}"' >> /root/.zshrc && \
    echo 'zstyle ":completion:*" menu select' >> /root/.zshrc && \
    echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /root/.zshrc && \
    echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc && \
    echo 'eval "$(oh-my-posh init zsh --config /etc/oh-my-posh/catppuccin_mocha.omp.json)"' >> /root/.zshrc && \
    echo 'alias ls="eza --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias ll="eza -l --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias la="eza -la --icons --group-directories-first"' >> /root/.zshrc && \
    echo 'alias tree="eza --tree --icons"' >> /root/.zshrc && \
    echo 'alias bat="batcat"' >> /root/.zshrc && \
    echo 'alias cat="batcat --paging=never"' >> /root/.zshrc

# ── Runtime user ───────────────────────────────────────────────────────────────
ENV RUNTIME_USER=kali
ENV RUNTIME_GROUP=kali
RUN useradd -m -s /bin/zsh $RUNTIME_USER && \
    echo "$RUNTIME_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$RUNTIME_USER && \
    cp /root/.zshrc /home/$RUNTIME_USER/.zshrc && \
    mkdir -p /home/$RUNTIME_USER/.local/bin && \
    cp -r /root/.local/bin/* /home/$RUNTIME_USER/.local/bin/ && \
    chown -R $RUNTIME_USER:$RUNTIME_GROUP /home/$RUNTIME_USER

CMD ["/bin/zsh"]
