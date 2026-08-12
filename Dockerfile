FROM ghcr.io/prefix-dev/pixi:noble AS build
LABEL "org.opencontainers.image.description"="A pixi-based Docker image for a robust cudem environment"

ARG BUILT_FROM_COMMIT
ENV BUILT_FROM_COMMIT=${BUILT_FROM_COMMIT}

##########################
######## Setup OS ########
##########################

# Use bash as default shell instead of sh
ENV SHELL=/bin/bash
# Don't buffer Python stdout/stderr output
ENV PYTHONBUFFERED=1
# Don't prompt in apt commands
ENV DEBIAN_FRONTEND=noninteractive

# Set up JupyterLab user
ENV NB_USER=jovyan
ENV NB_UID=1000
ENV USER="${NB_USER}"
ENV HOME="/home/${NB_USER}"
RUN userdel ubuntu \
 && groupadd \
  --gid ${NB_UID} \
  ${NB_USER} \
 && useradd \
  --comment "Default Jupyter user" \
  --create-home \
  --no-log-init \
  --uid ${NB_UID} \
  --gid ${NB_UID} \
  --shell ${SHELL} \
  ${NB_USER}

ENV DOCKER_WORKDIR=/workdir
WORKDIR ${DOCKER_WORKDIR}
RUN chown ${NB_UID}:${NB_UID} ${DOCKER_WORKDIR}

####################################
######## Setup dependencies ########
####################################

# System tools
RUN apt update && apt install -y curl gfortran make

USER ${NB_USER}

# Build and install HTDP
ENV HTDP_VERSION="v.3.6.0"
RUN mkdir ${DOCKER_WORKDIR}/htdp
WORKDIR ${DOCKER_WORKDIR}/htdp
RUN curl -L -O "https://github.com/noaa-ngs/HTDP/archive/refs/tags/${HTDP_VERSION}.tar.gz"
RUN tar -xvzf ${HTDP_VERSION}.tar.gz
RUN cd HTDP-${HTDP_VERSION} && make all FC=gfortran
USER root
RUN install HTDP-${HTDP_VERSION}/htdp /usr/bin
USER ${NB_USER}
WORKDIR ${DOCKER_WORKDIR}

# Build the Pixi environment
# TODO: Use pixi.lock instead of pixi.toml!?
COPY pixi.toml .
RUN pixi install \
 && rm -rf ~/.cache/rattler

# Set up shell activation script
RUN pixi shell-hook -s bash > ./shell-hook
USER root
ENV ENTRYPOINT_SCRIPT="/entrypoint.sh"
RUN echo "#!/bin/bash" > ${ENTRYPOINT_SCRIPT}
RUN cat ${PWD}/shell-hook >> ${ENTRYPOINT_SCRIPT}
RUN echo 'exec "$@"' >> ${ENTRYPOINT_SCRIPT}
RUN chmod +x ${ENTRYPOINT_SCRIPT}

USER ${NB_USER}
WORKDIR "/home/${NB_USER}"
EXPOSE 8888
ENTRYPOINT ["/entrypoint.sh"]
CMD ["jupyter", "lab", "--no-browser", "--ip=0.0.0.0"]
