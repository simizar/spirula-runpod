
FROM runpod/pytorch:1.5.0-cu1281-torch280-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display

RUN apt-get update && apt-get install -y \
    git cmake ninja-build build-essential \
    pkg-config python3 rclone \
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


# Install KasmVNC 1.5.0 for Ubuntu 24.04
RUN python3 - <<'PY'
import json
import urllib.request

url = "https://api.github.com/repos/kasmtech/KasmVNC/releases/tags/v1.5.0"
req = urllib.request.Request(
    url, headers={"User-Agent": "spirula-runpod-build"}
)

with urllib.request.urlopen(req) as response:
    release = json.load(response)

matches = [
    asset for asset in release["assets"]
    if "noble" in asset["name"].lower()
    and "amd64" in asset["name"].lower()
    and asset["name"].endswith(".deb")
]

if len(matches) != 1:
    raise RuntimeError(
        f"Expected one Noble amd64 package, found: {matches}"
    )

download_url = matches[0]["browser_download_url"]
print("Downloading:", matches[0]["name"])
urllib.request.urlretrieve(download_url, "/tmp/kasmvnc.deb")
PY

RUN apt-get update && \
    apt-get install -y /tmp/kasmvnc.deb && \
    rm -f /tmp/kasmvnc.deb && \
    rm -rf /var/lib/apt/lists/*


# Create desktop user
RUN useradd -m -s /bin/bash studio \
    && usermod -aG ssl-cert studio

EXPOSE 8444


# Copy desktop startup script
COPY start-desktop.sh /usr/local/bin/start-desktop.sh
COPY init-rclone.py /usr/local/bin/init-rclone.py

RUN chmod +x /usr/local/bin/start-desktop.sh

# Start KasmVNC automatically
CMD ["/usr/local/bin/start-desktop.sh"]

