# NCS development environment container

This repository hosts tools, packages, and various utilities required to run Zephyr RTOS applications inside a Docker container, specifically for the Nordic variant of Zephyr (NCS). The base Docker image uses Ubuntu 26.04. The built image is tagged with the latest commit hash, which makes it easy to pin a specific image version. The latest version can also be pulled with the `latest` tag.

The container contains the Nordic SDK (NCS), which avoids the need for applications to clone Zephyr every time the container is opened. The NCS version is specified in the `west.yml` file in this repository. Any additional repositories required by an application need to be specified in the application's own `west.yml` file located in its root directory.