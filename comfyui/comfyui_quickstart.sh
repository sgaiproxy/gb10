#!/usr/bin/env bash
set -euo pipefail

USER=`whoami`

echo Ensure you can run docker without sudo. 
echo If not, run the following 2 commands:
echo sudo usermod -aG docker $USER
echo newgrp docker

read -e -i 8188 -p "PORT to run ComfyUI: " COMFYUI_PORT

BASEDIR='/nfs/Data/comfyui'
COMFYUI_IMAGE='sgaiproxy/comfyui:latest'
read -e -i ${BASEDIR} -p "Path for comfyui models/input/output: " BASEDIR

###### Create persistent volume
if [[ -d ${BASEDIR} ]]; then
	echo ${BASEDIR} exists
else
	echo mkdir ${BASEDIR}
	mkdir -p $BASEDIR/models/checkpoints
	mkdir -p $BASEDIR/output
	mkdir -p $BASEDIR/input
	
	## download SD1.5 model
	cd $BASEDIR/models/checkpoints
	wget https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors
	
	## download vae model
	mkdir $BASEDIR/models/vae
	cd $BASEDIR/models/vae
	wget https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors
	
	## download text_encoders
	mkdir $BASEDIR/models/text_encoders
	cd $BASEDIR/models/text_encoders
	wget https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors
	
	## download diffusion model
	mkdir $BASEDIR/models/diffusion_models
	cd $BASEDIR/models/diffusion_models
	wget https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors
	
	chmod -R 777 $BASEDIR
fi


###### Launch comfyui container
CONTAINER_NAME="comfyui_${USER}"

if docker ps -a --format '{{.Names}}' | grep -wq "${CONTAINER_NAME}"; then
    echo "${CONTAINER_NAME} already running"
else
	echo docker run --rm -d \
	  --name ${CONTAINER_NAME} \
	  --gpus all \
	  -p ${COMFYUI_PORT}:8188 \
	  -v ${BASEDIR}/models:/opt/ComfyUI/models \
	   -v ${BASEDIR}/output:/opt/ComfyUI/output \
		-v ${BASEDIR}/input:/opt/ComfyUI/input \
	  ${COMFYUI_IMAGE}
	
	docker pull ${COMFYUI_IMAGE}
	docker run --rm -d \
	  --name ${CONTAINER_NAME} \
	  --gpus all \
	  -p ${COMFYUI_PORT}:8188 \
	   -v ${BASEDIR}/models:/opt/ComfyUI/models \
	   -v ${BASEDIR}/output:/opt/ComfyUI/output \
		-v ${BASEDIR}/input:/opt/ComfyUI/input \
	  ${COMFYUI_IMAGE}
fi

echo ${CONTAINER_NAME} running on port ${COMFYUI_PORT}
