FROM ubuntu:26.04

ARG project_dir=project
ARG toolchains_path=/opt/toolchains
ARG wget_args="-q --show-progress --progress=bar:force:noscroll"
ARG zephyr_ws=/home/ubuntu/zephyr_ws
ARG ccache_dir=${zephyr_ws}/${project_dir}/ccache
ARG west_update_args="--narrow -o=--depth=1 -o=--tags"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV ZEPHYR_WS=${zephyr_ws}
ENV ZEPHYR_BASE=${zephyr_ws}/zephyr
ENV CCACHE_DIR=${ccache_dir}

RUN \
apt-get update && \
apt-get install --no-install-recommends -y \
locales

RUN locale-gen en_US.UTF-8

RUN \
apt-get update && \
apt-get install --no-install-recommends -y \
bsdmainutils \
ca-certificates \
ccache \
clang-format \
clang-tidy \
clangd \
cmake \
device-tree-compiler \
file \
g++ \
gcc \
gdb \
git \
git-lfs \
gnupg \
libgmock-dev \
libgtest-dev \
libusb-1.0-0 \
make \
nano \
ninja-build \
openssh-client \
pkg-config \
python3-dev \
python3-pip \
python3-venv \
software-properties-common \
srecord \
sudo \
valgrind \
wget \
xxd \
xz-utils \
zip \
&& \
rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

# Disable password prompt for sudo commands
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Don't run as root
USER ubuntu
WORKDIR ${zephyr_ws}

RUN \
ARCH="$(dpkg --print-architecture)" && \
if [ "$ARCH" = "amd64" ]; then \
PACKAGE_VARIANT="x86_64"; \
elif [ "$ARCH" = "arm64" ]; then \
PACKAGE_VARIANT="aarch64"; \
else echo "Unsupported architecture"; false; \
fi; \
cd && \
wget ${wget_args} \
-O nrfutil \
"https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/${PACKAGE_VARIANT}-unknown-linux-gnu/nrfutil" && \
chmod +x nrfutil && \
sudo mv nrfutil /usr/bin/

RUN nrfutil self-upgrade
RUN nrfutil install device sdk-manager

# Initialize the base projects/modules specified in west.yml from this repository
# when building the image not to do it every time the container is created.
# This is done with west init using -l flag which tells it to initialize
# workspace from local west.yml instead of from remote repository.
# Do this inside temporary ${zephyr_ws}/${project_dir} directory to make sure
# that west update works once the repository is mounted to the container.
# Finally, add importing of west.yml located in the project directory.

ADD west.yml ${zephyr_ws}/west.yml

RUN \
python3 -m venv ${zephyr_ws}/.venv && \
. ${zephyr_ws}/.venv/bin/activate && \
pip install --no-cache-dir west codechecker pyyaml && \
sdk_version="$(python3 -c 'import yaml; manifest = yaml.safe_load(open("west.yml")); print(next(project["revision"] for project in manifest["manifest"]["projects"] if project["name"] == "nrf"))')" && \
nrfutil sdk-manager toolchain install --ncs-version "${sdk_version}" && \
nrfutil sdk-manager toolchain env --ncs-version "${sdk_version}" --as-script sh > /tmp/nrf-env.sh && \
sudo install -m 0644 /tmp/nrf-env.sh /opt/nrf-env.sh && \
rm /tmp/nrf-env.sh && \
rm -rf /home/ubuntu/ncs/downloads \
       /home/ubuntu/ncs/toolchains/*/opt/zephyr-sdk/riscv64-zephyr-elf && \
printf '%s\n' \
'source /usr/share/bash-completion/completions/git' \
'. /opt/nrf-env.sh' \
>> /home/ubuntu/.bashrc && \
mkdir -p ${zephyr_ws}/${project_dir} && \
cd ${zephyr_ws}/${project_dir} && \
west init --mf ../west.yml -l . && \
west config --local manifest.file "${zephyr_ws}/west.yml" && \
west update ${west_update_args} && \
west zephyr-export && \
west packages pip --install && \
rm -rf /home/ubuntu/.cache/pip && \
cd ${zephyr_ws} && \
rm -rf ${zephyr_ws}/${project_dir} && \
sudo tee -a west.yml <<EOF

  self:
    import: west.yml
EOF

ADD ./ ${zephyr_ws}/nenv
