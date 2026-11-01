
FROM runpod/pytorch:1.5.0-cu1281-torch280-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display

RUN apt-get update && apt-get install -y \
    git cmake ninja-build build-essential \
    pkg-config python3 \
    libvulkan-dev vulkan-tools \
    libgl1-mesa-dev libx11-dev \
    libxrandr-dev libxinerama-dev \
    libxcursor-dev libxi-dev \
    libwayland-dev libwayland-bin \
    wayland-protocols libxkbcommon-dev \
    xfce4 xfce4-terminal dbus-x11 \
    xauth x11-xserver-utils \
    ffmpeg curl wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/harry7557558/spirula-studio.git \
    && cd spirula-studio \
    && git checkout 6ad73ef \
    && bash build_develop.bash -DSS_BACKEND=vulkan

# KasmVNCと自動起動処理は次の工程で追加
