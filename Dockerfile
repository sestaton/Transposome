FROM ubuntu:18.04

LABEL maintainer "S. Evan Staton"
LABEL image_type "Transposome: Annotation of transposable element families from unassembled sequence reads"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    g++ make bzip2 gzip lib32z1 git ncbi-blast+ curl cpanminus \
    && rm -rf /var/lib/apt/lists/* \
    && cpanm git://github.com/sestaton/Transposome.git \
    && apt-get remove -y git cpanminus
