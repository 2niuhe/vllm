#!/bin/bash
set -e

echo "=========================================="
echo "vLLM Dev Container Post-Installation Script"
echo "=========================================="

# ============================================
# System Tools
# ============================================
echo "[1/5] Installing system tools..."
apt-get update && apt-get install -y --no-install-recommends \
    man \
    vim \
    cloc \
    ccache \
    htop \
    nvtop \
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
# Python Development Tools
# ============================================
echo "[2/5] Installing Python development tools..."
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
    jinja2

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
# Clone vLLM Source Code (if missing)
# ============================================
echo "[2.5/5] Checking for vLLM source code..."
cd /workspace

git clone https://github.com/vllm-project/vllm.git vllm
cd vllm


# ============================================
# Install vLLM in editable mode (development)
# ============================================
echo "[3/5] Installing vLLM in editable mode..."

# Clean previous build artifacts and caches
echo "Cleaning previous build artifacts..."
rm -rf /workspace/vllm/.deps
rm -rf /workspace/vllm/build
ccache -C
ccache -z

python use_existing_torch.py

# Enable ccache for C++ and CUDA compilation
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
uv pip install --python /opt/venv/bin/python3 --no-cache-dir -r requirements/build.txt
TORCH_CUDA_ARCH_LIST="8.6;8.9" MAX_JOBS=16 CCACHE_NOHASHDIR="true" uv pip install --python /opt/venv/bin/python3 -e . -v --no-build-isolation

echo "vLLM installed in editable mode"

# ============================================
# Download Models
# ============================================
echo "[4/5] Downloading models..."
export HF_HOME=/root/.cache/huggingface

# Dense model (small, for quick testing)
echo "Downloading Qwen3-0.6B..."
huggingface-cli download Qwen/Qwen3-0.6B
huggingface-cli download facebook/opt-125m
echo "Downloading Qwen3-Embedding-0.6B..."
huggingface-cli download Qwen/Qwen3-Embedding-0.6B

# ============================================
# Configure SSH Server
# ============================================
echo "[5/6] Configuring SSH server..."
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
echo "[6/6] Verifying installation..."
python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"
echo "Models cached at: $HF_HOME"
ls -la $HF_HOME/hub/

echo "=========================================="
echo "Post-installation complete!"
echo "=========================================="
