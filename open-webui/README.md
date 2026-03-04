
# Open WebUI

## Step 1: Download `open_webui_quickstart.sh`

Download the quickstart script:

```bash
wget -O open_webui_quickstart.sh https://raw.githubusercontent.com/sgaiproxy/gb10/main/open-webui/open_webui_quickstart.sh
chmod +x open_webui_quickstart.sh
```


## Step 2: Run the script

```bash
bash open_webui_quickstart.sh
```

Open WebUI should be accessible through:

- `http://localhost:8080` if accessing directly on the GB10 browser
- `http://<hostip>:8080` if accessing through the network

If you want to access it from your local device through port forwarding, proceed to Step 3.

## Step 3 (Optional): SSH local port forwarding

```bash
ssh -p <ssh port> -L 8080:localhost:8080 <user>@<host ip>
```

Open WebUI should be accessible through:

- `http://localhost:8080`


# To stop containers started by this process:
docker stop open-webui
docker stop ollama
docker stop vllm_qwen2_vl_2b_instruct
