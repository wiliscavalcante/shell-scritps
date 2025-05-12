###############################################################
# 1. COMMON DEPENDENCIES OF ALL AGRILEARN ECOSYSTEM 
###############################################################

# Base image for all agrilearn ecosystem (Python 3.10.12).
FROM dockerhub.agribusiness-brain.br.experian.eeca/ubuntu:22.04

# Information.
LABEL name="agrilearn-sits-bert"
LABEL description="Agrilearn crop classification model based on SITS-BERT architecture."
LABEL authors="RSM Products Team"

# New user parameters.
ARG USER_NAME=ec2-user
ARG USER_PASSWORD=ec2-user
ARG USER_UID=1000
ARG USER_GID=1000

# Proxy settings. ARG environment variables can be override at building time.
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG no_proxy

# Permanent proxy settings.
ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV no_proxy=${NO_PROXY}

# UV package manager env vars.
ENV UV_INSECURE_HOST="nexus.agribusiness-brain.br.experian.eeca"
ENV UV_INDEX_STRATEGY="unsafe-best-match"

# Set the timezone to avoid Jenkins stalling.
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Show if the image is being built for development or production. 
ARG IS_DEVELOPMENT
ENV IS_DEVELOPMENT=${IS_DEVELOPMENT}

# Install all required packages and add sudo support.
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    software-properties-common \   
    python3-pip \
    python3-dev \
    python-is-python3 \
    sudo \
    make \
    git \
    wget \
    curl \
    libgomp1 \
    netcat \
    vim \
    vim-gtk3 \
    nano \
    curl \
    unzip \
    tree 

# # Cleanup.
# RUN apt-get clean && \
#     apt-get autoremove -y && \
#     rm -rf /var/lib/apt/lists/*    

# Create the ec2-user with sudo privilegies.
RUN groupadd --gid $USER_GID $USER_NAME && \
    useradd --uid $USER_UID --gid $USER_GID --create-home $USER_NAME && \
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    adduser $USER_NAME sudo

# Set working directory (root of agrilearn ecosystem).
WORKDIR /agrilearn_app

# Folder where the model weights are stored.
ENV AGRILEARN_WEIGHTS_PATH="/agrilearn_app/weights/"

# This is necessary to avoid permission errors in pip installations.
RUN chown -R $USER_NAME:$USER_NAME /usr/local/

# No more root user. Switch to ec2-user.
USER $USER_NAME

# Remove annoying startup message.
RUN touch ~/.sudo_as_admin_successful

# Bash is now the default shell.
ENV SHELL=/bin/bash

# Update pip.
RUN pip install --upgrade pip

# Install UV python package manager.
RUN pip install uv

# Some important scripts are installed here (black, isort, uv).
ENV PATH=$PATH:/home/${USER_NAME}/.local/bin

# Enable prompt color in .bashrc.
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /home/$USER_NAME/.bashrc

# Debian apt-related tools with prompt.
ARG DEBIAN_FRONTEND=dialog

# Used in legacy code.
COPY ../.env.default /agrilearn_app/.env

# Default location for definitions of environmental variables.
ENV AGRILEARN_ENV_PATH=/agrilearn_app/.env

###############################################################
# 2. SPECIFIC DEPENDENCIES OF THIS AGRILEARN PACKAGE 
###############################################################

# Identify the module to the Workers Abstraction.
ENV MODULE_NAME=download

# Working directory.
WORKDIR /agrilearn_app/downloader

# All code copied inside the container.
COPY ../ /agrilearn_app/downloader

# Avoid permission errors in make commands.
RUN sudo chown -R $(whoami):$(whoami) /agrilearn_app

# Additional dependencies including newer versions of GDAL
RUN sudo add-apt-repository ppa:ubuntugis/ppa --yes && \
    sudo apt-get update --yes && \
    sudo apt-get install --yes \
    gcc \ 
    graphviz \
    libgomp1 \
    libgl1 \
    gpg-agent \
    gdal-bin \
    libgdal-dev 
    
# Cleanup again.
RUN apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
    
# GDAL configuration.
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

# Installs gdal on python (must be done as ec2-user).
RUN pip3 install GDAL==$(gdal-config --version)

# Location to the key for Google Earth Engine.
ENV GEE_KEY_PATH=/agrilearn_app/downloader/gee_key_dataops.json

# Google Earth Engine project name.
ENV GEE_PROJECT_NAME=

# Location to cache the eopatches (remote).
ENV EOPATCHES_CACHE=s3://agrilearn-eopatches-cache/cache_default/

# Cache folder of EoPatchDownloader (local).
ENV SENTINEL_CACHE_FOLDER=/agrilearn_app/cache/

# S3 name to the bucket of the mirror.
ENV SENTINEL_MIRROR_BUCKET_NAME=rsm-products-sentinel-mirror

# Install main packages dependencies and dev packages too.
RUN make install-dev-tools-too

# Use the entry point script.
ENTRYPOINT ["/agrilearn_app/downloader/entrypoint.sh"]
