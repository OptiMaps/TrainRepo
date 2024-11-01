# https://velog.io/@whattsup_kim/GPU-%EA%B0%9C%EB%B0%9C%ED%99%98%EA%B2%BD-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0-docker%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%98%EC%97%AC-%EA%B0%9C%EB%B0%9C%ED%99%98%EA%B2%BD-%ED%95%9C-%EB%B2%88%EC%97%90-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0

# Base Image
FROM nvidia/cuda:12.0.0-cudnn8-devel-ubuntu22.04
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Remove any third-party apt sources to avoid issues with expiring keys.
RUN rm -f /etc/apt/sources.list.d/*.list

# Install some basic utilities & python prerequisites
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install -y --no-install-recommends\
    vim \
    curl \
    apt-utils \
    ssh \
    tree \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    make \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    llvm \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    python3-openssl && \
    rm -rf /var/lib/apt/lists/*

# Set up time zone
ENV TZ=Asia/Seoul
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

# Add config for ssh connection
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config

# Create a non-root user and switch to it & Adding User to the sudoers File
ARG USER_NAME=user
ARG USER_PASSWORD=0000
RUN adduser --disabled-password --gecos '' --shell /bin/bash $USER_NAME && \
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER_NAME && \
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd 
USER $USER_NAME

# All users can use /home/user as their home directory
ENV HOME=/home/$USER_NAME
RUN mkdir $HOME/.cache $HOME/.config && \
    chmod -R 777 $HOME

# Create a workspace directory
RUN mkdir $HOME/workspace
WORKDIR $HOME/workspace

# Set up python environment with pyenv
ARG PYTHON_VERSION=3.10.6
RUN curl https://pyenv.run | bash
ENV PYENV_ROOT="$HOME/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
ENV eval="$(pyenv init -)"
RUN cd $HOME && /bin/bash -c "source .bashrc" && \
    /bin/bash -c "pyenv install -v $PYTHON_VERSION" && \
    /bin/bash -c "pyenv global $PYTHON_VERSION"

# Install Poetry
ENV PATH="$HOME/.local/bin:$PATH"
ENV PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring
RUN curl -sSL https://install.python-poetry.org | python - && \
    poetry config virtualenvs.in-project true && \ 
    poetry config virtualenvs.path "./.venv"

# [option] Set up DL development environment (with poetry)
RUN mkdir $HOME/workspace/machine-learning
WORKDIR $HOME/workspace/machine-learning
COPY pyproject.toml .
RUN /bin/bash -c "pyenv local $PYTHON_VERSION" && \
    poetry env use python3 && \
    poetry run poetry install --no-cache

# Install Python Packages
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip uninstall torch_geometric && \
    pip install torch_geometric==2.0.4 && \
    pip install --no-index pyg_lib torch_scatter torch_sparse torch_cluster torch_spline_conv -f https://data.pyg.org/whl/torch-1.13.0+cu117.html && \
	pip install -r requirements.txt && \
    pip cache purge && \
    pip install openbabel-wheel \
                fsspec \
                rdkit \
                pytorch-lightning \
                yacs \
                performer-pytorch \
                tensorboardX \
                ogb \
                wandb \
                jupyterlab && \
                pip install setuptools wheel packaging && \
                pip install --no-use-pep517 causal-conv1d mamba-ssm 


COPY entrypoint.sh .
RUN sudo chmod +x ./entrypoint.sh

COPY .env .
RUN mkdir ${HOME}/artifect

ENTRYPOINT ["/bin/bash","-c","./entrypoint.sh"]
