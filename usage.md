```bash
docker run -dit \
    --gpus all \
    --shm-size=32g \
    -p 2222:22 \
    -w /workspace \
    --name vllm-cuda-dev \
    vllm-cuda-ssh-dev:v0.15.1

# Connect to the container
ssh root@localhost -p 2222

# cpu version

docker run -it --rm \
    --shm-size=32g \
    -p 2222:22 \
    -w /workspace \
    --name vllm-cpu-dev \
    vllm-cpu-ssh-dev:v0.13.0 
```


------

build

```bash
docker build --build-arg max_jobs=16  -f docker/Dockerfile --target dev -t vllm-cuda-ssh-dev:v0.15.1 .




```