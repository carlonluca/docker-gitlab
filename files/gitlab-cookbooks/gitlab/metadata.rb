name "gitlab"
maintainer "GitLab.com"
maintainer_email "support@gitlab.com"
license "Apache 2.0"
description "Install and configure GitLab from Omnibus"
long_description "Install and configure GitLab from Omnibus"
version "0.0.1"
recipe "gitlab", "Configures GitLab from Omnibus"

supports "ubuntu"

depends "package"
depends 'postgresql'
depends 'redis'
depends 'prometheus'
depends 'registry'
depends 'mattermost'
depends 'consul'
depends 'gitaly'
depends 'letsencrypt'
depends 'nginx'
