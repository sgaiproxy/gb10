# ComfyUI in a container

## Step 1: Download `comfyui_quickstart.sh`

Download the quickstart script:

```bash
wget -O comfyui_quickstart.sh https://raw.githubusercontent.com/sgaiproxy/gb10/main/comfyui/comfyui_quickstart.sh
chmod +x comfyui_quickstart.sh
```


## Step 2: Run the script

```bash
bash comfyui_quickstart.sh
```

Open WebUI should be accessible through:

- `http://localhost:8188` if accessing directly on the GB10 browser
- `http://<hostip>:8188` if accessing through the network

If you want to access it from your local device through port forwarding, proceed to Step 3.

## Step 3 (Optional): SSH local port forwarding

```bash
ssh -p <ssh port> -L 8188:localhost:8188 <user>@<host ip>
```

Open WebUI should be accessible through:

- `http://localhost:8188`


# Tp stpp containers
```bash
docker stop comfyui_sgai
```
