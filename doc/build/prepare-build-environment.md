# Setting up a build environment

Omnibus GitLab provides docker images for all the OS versions that it
supports and these are available in the
[Container Registry](https://gitlab.com/gitlab-org/omnibus-gitlab/container_registry).
Users can use these images to setup the build environment. The steps are as
follows

1. Install docker. Visit [official docs](https://docs.docker.com/engine/installation)
   for more details.
2. Login to GitLab's registry

    You need a GitLab.com account to use the GitLab.com's container registry.
    Login to the registry using the command given below. Provide your username
    and password (you will have to create a
    [personal access token](https://docs.gitlab.com/ce/api/README.html#personal-access-tokens_)
    and use it instead of password, if you have enabled 2FA), when prompted.

    **Note:** Please keep in mind that your password/personal access token will
    be stored in the file `~/.docker/config.json`.

    ```
    docker login registry.gitlab.com
    ```
3. Pull the docker image for the OS you need to build package for

    Omnibus GitLab registry contains images for all the supported OSs and
    versions. You can use one of them to build a package for it. For example,
    to prepare a build environment for Debian Jessie, you have to pull its
    image. The revision of the image to be used is specified in `BUILDER_IMAGE_REVISION`
    variable in [.gitlab-ci.yml](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/.gitlab-ci.yml)
    file. Make sure you substitute that value to `${BUILDER_IMAGE_REVISION}`
    in the following commands.

    ```
    docker pull registry.gitlab.com/gitlab-org/gitlab-omnibus-builder:jessie-${BUILDER_IMAGE_REVISION}
    ```
4. Start the container and enter its shell

    ```
    docker run -it registry.gitlab.com/gitlab-org/gitlab-omnibus-builder:jessie-${BUILDER_IMAGE_REVISION} bash
    ```

5. Clone the Omnibus GitLab source and change to the cloned directory


    ```
    git clone https://gitlab.com/gitlab-org/omnibus-gitlab.git ~/omnibus-gitlab
    cd ~/omnibus-gitlab
    ```

6. Omnibus GitLab is optimized to use the internal repositories from
   dev.gitlab.org. These repositories are specified in the `.custom_sources.yml`
   file (specified by `remote` key) in the root of the source tree and will be
   used by default. Since these repositories are not publicly usable, for
   personal builds you have to use public alternatives of these repos. The
   alternatives are also provided in the same file, specified by `alternative`
   key. The selection between these two is controlled by `ALTERNATIVE_SOURCES`
   environment variable, which can be set either `true` or `false`. If that
   variable is set `true`, the repositories marked by `alternative` key will be
   used.

   Similarly, if you want to use your custom forks as sources, modify the
   `.custom_sources.yml` file and specify them as `alternate` and set the
   `ALTERNATIVE_SOURCES` variable to `true`.

7. Install the dependencies and generate binaries


    ```
    bundle install --path .bundle --binstubs
    ```

8. Run the build command to initiate a build process

    ```
    bin/omnibus build gitlab
    ```
    You can see the results of the build in the `pkg` folder at the root of the
    source tree.
