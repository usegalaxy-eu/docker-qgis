# Use the jlesage/baseimage-gui:ubuntu-22.04-v4 as base image
FROM jlesage/baseimage-gui:ubuntu-22.04-v4 AS build

MAINTAINER Bjoern Gruening, bjoern.gruening@gmail.com

RUN apt-get update -y && \
     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         ca-certificates \
         wget \
         unzip \
         libgl1 \
         qt5dxcb-plugin \
         ## needed for the QGIS plugin manager
         pip && \
     rm -rf /var/lib/apt/lists/*

# Install required packages for X11 and QGIS
RUN DEBIAN_FRONTEND=noninteractive apt update && apt install wget gnupg -y && \
    wget -O - https://qgis.org/downloads/qgis-2022.gpg.key | gpg --import && \
    gpg --export --armor D155B8E6A419C5BE | apt-key add - && \
    wget -O /etc/apt/keyrings/qgis-archive-keyring.gpg https://download.qgis.org/downloads/qgis-archive-keyring.gpg && \
    echo "Types: deb deb-src" > /etc/apt/sources.list.d/qgis.sources && \
    echo "URIs: https://qgis.org/debian" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Suites: jammy" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Architectures: amd64" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg" >> /etc/apt/sources.list.d/qgis.sources && \    
    apt-get update && apt-get install -y qgis qgis-plugin-grass && \
    apt-get update && apt-get install -y qgis qgis-plugin-grass && \
    rm -rf /var/lib/apt/lists/*

COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh && \
    mkdir -p /app/qgis
    
# Set the name of the application.
ENV APP_NAME="QGIS"
ENV APP_VERSION="3.32"

ENV KEEP_APP_RUNNING=0

ENV TAKE_CONFIG_OWNERSHIP=1

# Set environment
ENV JAVA_HOME /opt/jdk
ENV PATH ${PATH}:${JAVA_HOME}/bin
WORKDIR /app/qgis

USER root

# Add pluggins to the QGIS tool (just Trends.Earth for now)
# You can just download here the zip folder for your plugins
RUN pip install qgis-plugin-manager &&\
    # special trends earth manip to counter path issues (should contact the authors to fix this in their code)
    mkdir -p /root/trends_earth_data/reports/outputs/ && \
    # trends earth again
    mkdir /root/trends_earth_data/reports/templates && \
    # trends earth again
    touch /root/trends_earth_data/reports/templates/templates.json && \
    #Back to the general plugin installation
    mkdir -p /root/.local/share/QGIS/QGIS3/profiles/default/python/plugins/ &&\
    cd /root/.local/share/QGIS/QGIS3/profiles/default/python/plugins/ &&\
    qgis-plugin-manager init && \
    qgis-plugin-manager update && \
    ##qgis-plugin-manager install trends.earth && \
    qgis-plugin-manager install 'Hugin QGIS' && \
    qgis-plugin-manager install 'Mask' && \
    qgis-plugin-manager install 'trends.earth' &&\
    #qgis-plugin-manager install 'CanFlood' && \
    #qgis-plugin-manager install 'GeoCoding' && \
    mkdir -p ${HOME}/.local/share/ &&\
    #ln -s /config/xdg/data/QGIS ${HOME}/.local/share/ && \
    #export XDG_DATA_HOME=/config/xdg/data && \
    #export XDG_CONFIG_HOME=/config/xdg/config && \
    export QT_QPA_PLATFORM=offscreen &&\
    qgis_process.bin plugins enable hugin_qgis &&\
    qgis_process.bin plugins enable mask &&\
    #Next is trends earth plugin (different name don't know why)
    qgis_process.bin plugins enable LDMP &&\ 
    #qgis_process.bin plugins enable canflood &&\
    #qgis_process.bin plugins enable GeoCoding &&\
    unset QT_QPA_PLATFORM

WORKDIR /config
