#!/bin/bash
set -e

echo "==========================================="
echo "vLLM CPU Dev Container Post-Installation Script"
echo "==========================================="

# ============================================
# System Tools (CPU-specific, no GPU tools)
# ============================================
echo "[1/6] Installing system tools..."
apt-get update && apt-get install -y --no-install-recommends \
    man \
    vim \
    cloc \
    ccache \
    htop \
    tmux \
    tree \
    jq \
    ripgrep \
    fd-find \
    gdb \
    build-essential \
    zsh \
    openssh-server \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Python Development Tools (CPU-specific)
# ============================================
echo "[2/6] Installing Python development tools..."
uv pip install --no-cache-dir \
    pip \
    debugpy \
    ipdb \
    py-spy \
    memory_profiler \
    ruff \
    jupyterlab \
    ipython \
    rich \
    line_profiler \
    tqdm

# Persist environment variables for SSH login
export HF_HOME=/root/.cache/huggingface
export PATH="/opt/venv/bin:/root/.local/bin:$PATH"
export VIRTUAL_ENV="/opt/venv"

cat >> ~/.bashrc << 'EOF'
# vLLM dev environment
export PATH="/opt/venv/bin:/root/.local/bin:$PATH"
export VIRTUAL_ENV="/opt/venv"
export HF_HOME=/root/.cache/huggingface
EOF

# ============================================
# Clone vLLM Source Code (fresh from GitHub)
# ============================================
echo "[3/6] Cloning vLLM source code..."
cd /workspace

# Remove existing source if present (from Docker COPY)
rm -rf vllm
git clone https://github.com/vllm-project/vllm.git vllm
cd vllm

# ============================================
# Install vLLM in editable mode (CPU target)
# ============================================
echo "[4/6] Installing vLLM in editable mode for CPU..."

python use_existing_torch.py

# Enable ccache for C++ compilation
export CMAKE_CXX_COMPILER_LAUNCHER=ccache

# Install in editable mode with CPU target
VLLM_TARGET_DEVICE=cpu MAX_JOBS=16 CCACHE_NOHASHDIR="true" uv pip install --python /opt/venv/bin/python3 -e . -v --no-build-isolation

echo "vLLM installed in editable mode (CPU)"

# ============================================
# Download Models (CPU-compatible, no FP8)
# ============================================
echo "[5/6] Downloading models..."
export HF_HOME=/root/.cache/huggingface

# Dense model (small, CPU-compatible)
echo "Downloading Qwen3-0.6B..."
huggingface-cli download Qwen/Qwen3-0.6B
huggingface-cli download facebook/opt-125m

echo "Downloading Qwen3-Embedding-0.6B..."
huggingface-cli download Qwen/Qwen3-Embedding-0.6B

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
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
EOF
chmod +x /usr/local/bin/docker-entrypoint.sh

# ============================================
# Verification
# ============================================
echo "Verifying installation..."
python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"
echo "Models cached at: $HF_HOME"
ls -la $HF_HOME/hub/

echo "==========================================="
echo "CPU Post-installation complete!"
echo "==========================================="
