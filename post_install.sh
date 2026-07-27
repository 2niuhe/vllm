#!/bin/bash
set -Eeuo pipefail

echo "=========================================="
echo "vLLM Dev Container Post-Installation Script"
echo "=========================================="

# ============================================
# System Tools
# ============================================
echo "[1/6] Installing system tools..."
apt-get update && apt-get install -y --no-install-recommends \
    bash-completion \
    man \
    protobuf-compiler \
    vim \
    cloc \
    ccache \
    htop \
    nvtop \
    tmux \
    tree \
    wget \
    curl \
    git \
    jq \
    ripgrep \
    fd-find \
    fzf \
    less \
    gdb \
    build-essential \
    zsh \
    openssh-server \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y --no-install-recommends nodejs && rm -rf /var/lib/apt/lists/*
npm install -g @openai/codex
npm install -g @anthropic-ai/claude-code

# ============================================
# Interactive Shell and Rust
# ============================================
echo "[2/6] Configuring Zsh and Rust..."

# Keep the install non-interactive so Docker builds do not hang. Do not let the
# installer change the shell itself; usermod below does that explicitly.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ ! -x "$HOME/.cargo/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --profile minimal --default-toolchain stable
fi
. "$HOME/.cargo/env"
rustc --version
cargo --version

append_shell_config() {
    local shell_rc="$1"

    if ! grep -Fq '# >>> vLLM dev environment >>>' "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << 'EOF'

# >>> vLLM dev environment >>>
export PATH="/opt/venv/bin:$HOME/.local/bin:$PATH"
export VIRTUAL_ENV="/opt/venv"
export HF_HOME="$HOME/.cache/huggingface"
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi
# <<< vLLM dev environment <<<
EOF
    fi
}

append_shell_config "$HOME/.bashrc"
append_shell_config "$HOME/.zshrc"

# Ensure SSH and interactive terminals start in Zsh for the image's root user.
usermod --shell "$(command -v zsh)" root

# ============================================
# Python Development Tools
# ============================================
echo "[3/6] Installing Python development tools..."
uv pip install --no-cache-dir \
    pip \
    debugpy \
    ipdb \
    py-spy \
    memory_profiler \
    nvitop \
    ruff \
    jupyterlab \
    ipython \
    rich \
    line_profiler \
    tqdm \
    "setuptools>=77.0.3,<81.0.0" \
    "setuptools-scm>=8.0" \
    "cmake>=3.26.1" \
    ninja \
    "packaging>=24.2" \
    wheel \
    jinja2 \
    modelscope

# Set environment variables for the remainder of this installation. They are
# persisted for interactive Bash and Zsh sessions above.
export HF_HOME=/root/.cache/huggingface
export PATH="/opt/venv/bin:/root/.local/bin:$PATH"
export VIRTUAL_ENV="/opt/venv"

# ============================================
# Clone vLLM Source Code (if missing)
# ============================================
echo "[3.5/6] Checking for vLLM source code..."
cd /workspace

git clone https://github.com/vllm-project/vllm.git vllm
cd vllm


# ============================================
# Install vLLM in editable mode (development)
# ============================================
echo "[4/6] Installing vLLM in editable mode..."

# Clean previous build artifacts and caches
echo "Cleaning previous build artifacts..."
rm -rf /workspace/vllm/.deps
rm -rf /workspace/vllm/build
ccache -C
ccache -z

/opt/venv/bin/python use_existing_torch.py

# Enable ccache for C++ and CUDA compilation
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
uv pip install --python /opt/venv/bin/python3 --no-cache-dir -r requirements/build/cuda.txt
TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9" MAX_JOBS=16 CCACHE_NOHASHDIR="true" uv pip install --python /opt/venv/bin/python3 -e . -v --no-build-isolation

echo "vLLM installed in editable mode"

# ============================================
# Download Models
# ============================================
echo "[5/6] Downloading models..."
export HF_HOME=/root/.cache/huggingface


# ============================================
# Configure SSH Server
# ============================================
echo "[6/6] Configuring SSH server..."
mkdir -p /var/run/sshd
echo 'root:password' | chpasswd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create entrypoint script
cat > /usr/local/bin/docker-entrypoint.sh << 'EOF'
#!/bin/sh
service ssh start

JUPYTER_PORT="${JUPYTER_PORT:-8888}"
JUPYTER_LOG="${JUPYTER_LOG:-/var/log/jupyterlab.log}"
JUPYTER_ALLOW_ORIGIN="${JUPYTER_ALLOW_ORIGIN:-*}"
JUPYTER_ALLOW_REMOTE_ACCESS="${JUPYTER_ALLOW_REMOTE_ACCESS:-True}"
JUPYTER_DISABLE_CHECK_XSRF="${JUPYTER_DISABLE_CHECK_XSRF:-True}"

jupyter lab \
  --ip=0.0.0.0 \
  --port="${JUPYTER_PORT}" \
  --no-browser \
  --allow-root \
  --ServerApp.token="${JUPYTER_TOKEN:-}" \
  --ServerApp.password="${JUPYTER_PASSWORD:-}" \
  --ServerApp.allow_origin="${JUPYTER_ALLOW_ORIGIN}" \
  --ServerApp.allow_remote_access="${JUPYTER_ALLOW_REMOTE_ACCESS}" \
  --ServerApp.disable_check_xsrf="${JUPYTER_DISABLE_CHECK_XSRF}" \
  > "${JUPYTER_LOG}" 2>&1 &

if [ $# -eq 0 ]; then
  exec tail -f /dev/null
else
  exec "$@"
fi
EOF
chmod +x /usr/local/bin/docker-entrypoint.sh

# ============================================
# Verification
# ============================================
echo "Verifying installation..."
/opt/venv/bin/python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"

echo "=========================================="
echo "Post-installation complete!"
echo "=========================================="
