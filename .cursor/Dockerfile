FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        git-lfs \
        unzip \
        xz-utils \
        libx11-6 \
        libxcursor1 \
        libxinerama1 \
        libxrandr2 \
        libxi6 \
        libxext6 \
        libxfixes3 \
        libxrender1 \
        libgl1 \
        libglu1-mesa \
        libasound2t64 \
        libpulse0 \
        libfontconfig1 \
        libdbus-1-3 \
        libxkbcommon0 \
        libwayland-client0 \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu
WORKDIR /workspace
