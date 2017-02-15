# Setting up your development environment

Development of Omnibus GitLab maybe done using an existing package available
from [Downloads page](https://about.gitlab.com/downloads). To know how to setup
a build environment to build these packages and use them, please read [Setting
up a Build Environment](../build/prepare-build-environment.md).

 1. Setup a VM

    To provide isolation and to prevent rebuilding of the package for each and
    every change, it is preferred to use a Virtual Machine for development. The
    following example uses docker on a Debian host with a Debian Jessie image.
    The steps are similar for other OSs; only the commands differ.
    1. Installing docker

        ```
        sudo apt-get install docker
        ```
    For information about installing Docker on other OSs, visit
    [official Docker installation docs](https://docs.docker.com/engine/installation).

    2. Pulling a Debian Jessie image

        ```
        docker pull debian:jessie
        ```

    3. Running docker image with a shell prompt

        ```
        docker run -it debian:jessie bash
        ```
    This will cause the docker to run the jessie image and you will fall into a
    bash prompt, where the following steps are applied to.

 2. Install basic necessary tools

    Basic tools used for developing Omnibus GitLab may be installed using the
    following command

    ```
    sudo apt-get install git
    ```

 3. Getting GitLab CE nightly package and installing it

    Get the latest GitLab CE nightly package (of the OS you are using) from
    [Nightly Build repository](https://packages.gitlab.com/gitlab/nightly-builds)
    and install it using the instructions given on that page. Once you configure
    and start gitlab. Check if you can access it from your host browser on
    \<ip address of host>

 4. Getting source of Omnibus GitLab

    Get the source code of Omnibus GitLab from the [repository on GitLab.com](https://gitlab.com/gitlab-org/omnibus-gitlab)

    ```
    git clone https://gitlab.com/gitlab-org/omnibus-gitlab.git ~/omnibus-gitlab
    ```

    We will be doing the development inside the `~/omnibus-gitlab` directory.

 5. Instructing GitLab to apply the changes we make to the cookbooks.

    During development, we need the changes we make to the cookbooks to be
    applied immediately to the running GitLab instance. So, we have to instruct
    GitLab to use those cookbooks instead of the ones shipped during
    installation. This involves backing up of the existing cookbooks directory
    and symlinking the directory where we make modifications to its location.

    ```
    sudo mv /opt/gitlab/embedded/cookbooks/gitlab /opt/gitlab/embedded/cookbooks/gitlab.$(date +%s)
    sudo ln -s ~/omnibus-gitlab/files/gitlab-cookbooks/gitlab /opt/gitlab/embedded/cookbooks/gitlab
    ```

Now, you can make necessary changes in the
`~/omnibus-gitlab/files/gitlab-cookbooks/gitlab` folder and run `sudo gitlab-ctl reconfigure`
for those changes to take effect.

## Openshift GitLab Development Setup

See [openshift/README.md.](openshift/README.md#development-setup)
