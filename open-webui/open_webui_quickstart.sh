#!/usr/bin/env bash
set -euo pipefail
BASEDIR='/nfs'
USER=`whoami`

echo Ensure you can run docker without sudo. 
echo If not, run the following 2 commands:
echo sudo usermod -aG docker $USER
echo newgrp docker


NETWORK="openwebui-network"
WEBUI_CONTAINER="open-webui"
OLLAMA_CONTAINER="ollama"
VLLM_CONTAINER="vllm_qwen2_vl_2b_instruct"
WEBUI_PORT=8080
OLLAMA_PORT=11434
VLLM_PORT=8719

read -e -i ${NETWORK} -p "Name for openwebui network: " NETWORK
read -e -i ${WEBUI_PORT} -p "PORT to run WEBUI: " WEBUI_PORT
read -e -i ${WEBUI_CONTAINER} -p "NAME for open-webui container: " WEBUI_CONTAINER
read -e -i ${OLLAMA_PORT} -p "PORT to run ollama server: " OLLAMA_PORT
read -e -i ${OLLAMA_CONTAINER} -p "NAME for ollama server container: " OLLAMA_CONTAINER
read -e -i ${VLLM_PORT} -p "PORT to run vllm qwen2-vl-2b-instruct: " VLLM_PORT
read -e -i ${VLLM_CONTAINER} -p "NAME for vllm qwen2-vl-2b-instruct container: " VLLM_CONTAINER


if ! docker network inspect "${NETWORK}" >/dev/null 2>&1; then
    docker network create "${NETWORK}"
fi

############################
# start ollama server
############################


if docker ps -a --format '{{.Names}}' | grep -wq "${OLLAMA_CONTAINER}"; then
	echo "${OLLAMA_CONTAINER} already running"
else
	echo docker run -d --rm \
	  --network ${NETWORK} \
	  --gpus=all \
	  -v ollama:/root/.ollama \
	  --name ${OLLAMA_CONTAINER} \
	  -p ${OLLAMA_PORT}:11434 \
	  ollama/ollama
	
	docker run -d \
	  --network ${NETWORK} --rm \
	  --gpus=all \
	  -v ollama:/root/.ollama \
	  --name ${OLLAMA_CONTAINER} \
	  -p ${OLLAMA_PORT}:11434 \
	  ollama/ollama
fi  

#############################################################
# Download models
# Visit https://www.ollama.com/search for full list of models available
#############################################################
echo "Pulling gpt-oss:120b and granite3.2-vision:latest"
echo docker exec ${OLLAMA_CONTAINER} ollama pull gpt-oss:120b
docker exec ${OLLAMA_CONTAINER} ollama pull gpt-oss:120b
echo docker exec ${OLLAMA_CONTAINER} ollama pull granite3.2-vision:latest
docker exec ${OLLAMA_CONTAINER} ollama pull granite3.2-vision:latest



################################################################################
# Install git-lfs if missing
################################################################################
if ! command -v git-lfs >/dev/null 2>&1; then
  echo "Installing git-lfs"
  sudo apt update
  sudo apt install -y git-lfs
fi

echo Run git lfs install
git lfs install


################################################################################
# Clone Qwen model to /nfs
################################################################################
MODEL_BASE_DIR="${BASEDIR}/llm_models"
MODEL_ID='Qwen/Qwen2-VL-2B-Instruct'
MODEL_DIR="${MODEL_BASE_DIR}/${MODEL_ID}"

if [[ -d ${MODEL_DIR} ]]; then 
	echo ${MODEL_DIR} exists
else
	MODEL_VENDOR="${MODEL_ID%%/*}"
	sudo mkdir -p ${MODEL_BASE_DIR}/${MODEL_VENDOR}
	echo clone ${MODEL_ID}
	echo git clone https://huggingface.co/${MODEL_ID} "$MODEL_DIR"
	git clone https://huggingface.co/${MODEL_ID} "$MODEL_DIR"
fi

################################################################################
# Run vLLM server
################################################################################
echo "Starting vLLM"

if docker ps -a --format '{{.Names}}' | grep -wq "${VLLM_CONTAINER}"; then
	echo "${VLLM_CONTAINER} already running"
else
	export TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas
	export PATH=/usr/local/cuda/bin:$PATH
	if [[ -z "${LD_LIBRARY_PATH+x}" ]]; then
		export LD_LIBRARY_PATH=/usr/local/cuda/lib64
	else
		export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
	fi
	export TORCH_CUDA_ARCH_LIST="12.1a"
	
	echo docker run -d -e TRITON_PTXAS_PATH -e PATH -e LD_LIBRARY_PATH -e TORCH_CUDA_ARCH_LIST \
	-p ${VLLM_PORT}:8000 \
	--gpus all --rm -v ${MODEL_BASE_DIR}:${MODEL_BASE_DIR} --network ${NETWORK} --name ${VLLM_CONTAINER} \
	vllm/vllm-openai:v0.11.2 ${MODEL_BASE_DIR}/${MODEL_ID} --host 0.0.0.0 --max-model-len 32000 --gpu-memory-utilization 0.8
	
	docker run -d -e TRITON_PTXAS_PATH -e PATH -e LD_LIBRARY_PATH -e TORCH_CUDA_ARCH_LIST \
	-p ${VLLM_PORT}:8000 \
	--gpus all --rm -v ${MODEL_BASE_DIR}:${MODEL_BASE_DIR} --network ${NETWORK} --name ${VLLM_CONTAINER} \
	vllm/vllm-openai:v0.11.2 ${MODEL_BASE_DIR}/${MODEL_ID} --host 0.0.0.0 --max-model-len 32000 --gpu-memory-utilization 0.8
fi




#############################################################
#Run open-webui
#############################################################
echo "Starting Open WebUI"

if docker ps -a --format '{{.Names}}' | grep -wq "${WEBUI_CONTAINER}"; then
	echo "${WEBUI_CONTAINER} already running"
else
	echo docker run -d --rm \
	  -p ${WEBUI_PORT}:8080 \
	  --network ${NETWORK} \
	  --gpus=all \
	  -e WEBUI_AUTH=False \
	  -e OLLAMA_BASE_URL=http://${OLLAMA_CONTAINER}:11434 \
	  -e OPENAI_API_BASE_URL=http://${VLLM_CONTAINER}:8000/v1 \
	  -e OPENAI_API_KEY=EMPTY \
	  -v open-webui:/app/backend/data \
	  --name ${WEBUI_CONTAINER} \
	  ghcr.io/open-webui/open-webui:cuda
	  
	docker run -d --rm \
	  -p ${WEBUI_PORT}:8080 \
	  --network ${NETWORK} \
	  --gpus=all \
	  -e WEBUI_AUTH=False \
	  -e OLLAMA_BASE_URL=http://${OLLAMA_CONTAINER}:11434 \
	  -e OPENAI_API_BASE_URL=http://${VLLM_CONTAINER}:8000/v1 \
	  -e OPENAI_API_KEY=EMPTY \
	  -v open-webui:/app/backend/data \
	  --name ${WEBUI_CONTAINER} \
	  ghcr.io/open-webui/open-webui:cuda
fi


echo If you need to perform ssh local port forwarding, do the following in your local device command prompt
echo 'ssh -p <your ssh port> -L ${WEBUI_PORT}:localhost:${WEBUI_PORT} ${USER}@<your gb10 ip addr>'
