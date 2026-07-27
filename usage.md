# Usage

```bash
docker run -dit \
    --gpus all \
    --shm-size=32g \
    -p 2222:22 \
    -p 8888:8888 \
    -w /workspace \
    --name vllm-cuda-dev \
    vllm-cuda-ssh-dev:v0.22.1

# Connect to the container
ssh root@localhost -p 2222

```

------

build

```bash
docker build --build-arg max_jobs=16  -f docker/Dockerfile --target dev -t vllm-cuda-ssh-dev:v0.23.0 .




```
