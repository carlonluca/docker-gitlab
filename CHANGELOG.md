# Omnibus-gitlab changelog

The latest version of this file can be found at the master branch of the
omnibus-gitlab repository.

8.7.8

- Update version of pcre
- Update version of expat

8.7.7

- No changes

8.7.3

- Update openssl to 1.0.2h

8.7.2

- No changes

8.7.1

- Package supports Ubuntu 16.04 8a4ce1f5
- Pin versions of ohai and chef-zero to prevent reconfigure outputting too much info f9b2307c

8.7.0

- Added db_sslca to the configuration options for connecting to an external database 2b4033cb
- Compile NGINX with the real_ip module and add configuration options b4830b90
- Added trusted_proxies configuration option for non-bundled web-server 3f137f1c
- Support the ability to change mattermost UID and GID c5a588da
- Updated libicu to 56.1 4de944d9
- Updated liblzma to 5.2.2 4de944d9
- Change the way db:migrate is triggered 3b42520a
- Allow Omniauth providers to be marked as external 7dd68edf
- Enable Git LFS by default (Ben Bodenmiller) 22345799
- Updated how we detect when to update the :latest and :rc docker build tags cb3af445
- Disable automatic git gc 8ed13f4b
- Restart GitLab pages daemon on version change 922f7655
- Add git-annex to the docker image c1fdc4ff
- Update Nginx to 1.9.12 96ca0916
- Update Mattermost to v2.2.0 fd740e17
- Update cacerts to 2016.04.20  edefbe2e
- Add configuration for geo_bulk_notify_worker_cron 219125bf
- Add configuration repository_archive_cache_worker_cron 8240ab3a
- Update the docker update-permissions script 13343b4f
- Add SMTP ssl configuration option (wu0407) 4a377fc2
- Build curl dependency without libssh2 17e41f8

8.6.6

- No changes

8.6.5

- No changes

8.6.4

- No changes

8.6.3

- No changes

8.6.2

- Updated chef version to 12.6.0 37bf798
- Use `:before` from Chef 12.6 to enable extension before migration or database seed fd6c88e0

8.6.1

- Fix artifacts path key in gitlab.yml.erb c29c1a5d

8.6.0

- Update redis version to 2.8.24 2773274
- Pass listen_network of gitlab_workhorse to gitlab nginx template 51b20e2
- Enable NGINX proxy caching 8b91c071
- Restart unicorn when bundled ruby is updated aca3cb2
- Add ability to use dateformat for logrotate configuration (Steve Norman) 6667865d
- Added configuration option that allows disabling http2 protocol bcaa9e9
- Enable pg_trgm extension for packaged Postgres f88fe25
- Update postgresql to 9.2.15 to address CVE-2016-0773 (Takuya Noguchi) 16bf321
- If gitlab rails is disabled, reconfigure needs to run without errors 5e695aac
- Update mattermost to v2.1.0 f555c232
- No static content delivery via nginx anymore as we have workhorse (Artem Sidorenko) 89b72505
- Add configuration option to disable management of storage directories 81a370d3

8.5.10

- No changes

8.5.9

- No changes

8.5.8

- Bump Git version to 2.7.4

8.5.7

- Bump Git version to 2.7.3

8.5.6

- No changes

8.5.5

- Add ldap_sync_time global configuration as the EE is still supporting it 3a58bfd

8.5.4

- No changes

8.5.3

- No changes

8.5.2

- Fix regression where NGINX config for standalone ci was not created d3352a78b4c3653d922e415de5c9dece1d8e10f8
- Update openssl to 1.0.2g 0e44b8e91033f3e1662c8ea92641f1a653b5b871

8.5.1

- Push Raspbian repository for RPI2 to packagecloud 57acdde0465ed9213726d84e2b92545344449002
- Update GitLab pages daemon to v0.2.0 326add9babb605d4116da22dcfa30ed1aa12271f
- Unset env variables that could interfere with gitlab-rake and gitlab-rails commands e72a6f0e256dc6cc415248ce6bc63a5580bb22f6

8.5.0

- Add experimental support for relative url installations (Artem Sidorenko) c3639dc311f2f70ec09dcd579a09443189266864
- Restart mailroom service when a config changes f77dcfe9949ba6a425c448aff34fdb9cbe289164
- Remove gitlab-ci standalone from the build, not all gitlab-ci code de6419c850d0302a230b172c06d9e542845bc5b7
- Switch openssl to 1.0.2f a53d77674f32de055e7f6b4128e25ff7c801a284
- Update nginx to 1.9.10 8201623411c028202392d7f90056e1494812ced0
- Use http2 module 8201623411c028202392d7f90056e1494812ced0
- Update omnibus to include -O2 compiler flag e9acc03ca296f9146fd5824e8818861c7b584a63
- Add configuration options to override default proxy headers 3807ed87ec887ca60343a5dc09fc99af746e1535
- Change permissions of public/uploads directory to be more restrictive 7e4aa2f5e60cbb8a5f6c6475514a73be813b74fe
- Update mattermost to v2.0.0 8caacf73e23c930bab286b0affbf1a3c0bd93361
- Add support for gitlab-pages daemon 0bbaba4d698306f5a2640cdf915129f5e6dd6d80
- Added configuration options for new allow_single_sign_on behavior and auto_link_saml_user 96ba41274864857f494e220a684e9e34954c85d1

8.4.8

- No changes

8.4.7

- No changes

8.4.6

- No changes

8.4.5

- No changes

8.4.4

- Allow webserver user to access the gitlab pages e0cbafafad88d2478514c1485f69fc41cc076a85

8.4.3

- Update openssl to 1.0.1r 541a0ed432bfa6a5eac58be7aeb70b15b1b6ea43

8.4.2

- Update gitlab-workhorse to 0.6.2 32b3a74179e28c1572608cc62c1484caf907cb9c

8.4.1

- No changes

8.4.0

- Add support for ecdsa and ed25519 keys to Docker image (Matthew Monaco) 3bfcb2617d240937fdb77d38900ee00f1ffbce02
- Pull the latest base image before building the GitLab Docker image (Ben Sjoberg) c9926773d708b7e94cd70b190e213ae322dbee17
- Remove runit files when service is disabled 8c4c446c2ba42cf8a76d9a61882ac0605f678532
- Add GITLAB_OMNIBUS_CONFIG to Docker image bfe5cb8187b0c05778fe401c2a6bbbd31b1efe2e
- Compile all .py files during packaging b131e0fc0562c416fd62d84f43a6b3e3a03baa23
- Correctly update md5sums for deb packager b131e0fc0562c416fd62d84f43a6b3e3a03baa23
- Fix syntax for md5sums file b131e0fc0562c416fd62d84f43a6b3e3a03baa23
- Update git to use symlinks for alias commands 65df6a4dcfc89557ec8413e8e967242f4db96dba
- Remove libgit definition and rely on it being built by rugged fe38fa17db9e855f2a844a1b68a4aaf2ac169184
- Update ruby to 2.1.8 6f1d4204ca24f67bbf453c7d751ba7977c23f55e
- Update git to 2.6.2 6f1d4204ca24f67bbf453c7d751ba7977c23f55e
- Ensure that cache clear is run after db:migrate b4dfb1f7b493ae5ef5fabda5c04e2dee6f4b849e
- Add support for Elasticsearch config (EE only) 04961dd0667c7eb5946836ffae6a5d6f6c3d66e0
- Update cacerts to 2016.01.20 8ddedf2effd8944bd79b46682ce48a1c8f635c76
- Change the way version is specified for gitlab-rails, gitlab-shell and gitlab-workhorse a8676c647aca93c428335d35350f00bf757ee42a
- Update Mattermost to v1.4.0 82149cf5fa9d556be558b69867c0859ea15e1a64
- Add config for specifying environmental variables for gitlab-workhorse 79b807649d54384ddf93b214b2a23d7a2180b48e
- Increase default Unicorn memory limits to 300-350 814ee578bbfe1f9eb2a83a9c728cd56565e89cb8
- Forward git-annex config to gitlab.yml 796a0d9875b2c7d889878a2db29bb4689cd64b64
- Prevent mailroom from going into restart loop 378f2355c5e9728c43baf14595bf9362c03b8b4c
- Add gitlab-workhorse config for proxy_headers_timeout d3de62c54b5efe1d5f60c2dccef65e786b631c3b
- Bundle unzip which is required for EE features 56e1fc0b11cd2fb5458fa8a9585d3a1f4faa8d6f

8.3.7

- No changes

8.3.6

- No changes

8.3.5

- No changes

8.3.4

- Update gitlab-workhorse to 0.5.4 7968c80843ac7deaaebe313c6976615a2268ac03

8.3.3

- Update gitlab-workhorse to 0.5.3 6fbe783cfd677ea16fcfe1e1090887e5ee0a0028

8.3.2

- No changes

8.3.1

- Increase default worker memory from 250MB to 300MB.
- Update GitLab workhorse to 0.5.1 cd01ed859e6ace690a4f57a8c16d56a8fd1b7b47
- Update rubygemst to 2.5.1 58fcbbdb31a3e6ea478e223c659634e60d82e191
- Update libgit2 to 0.23.4 and let rugged be compiled during bundle install fb54c1f0f2dc4f122d814de408f4d751f7cc8ed5

8.3.0

- Add sidekiq concurrency setting 787aa2ffc3b50783ae17e32d69e4b8efae8ca9ac
- Explicitly create directory that holds the logs 50caed92198aef685c8e7815a67bcb13d9ebf911
- Updated omnibus to v5.0.0 18835f14453fd4fb834d228caf1bc1b37f1fe910
- Change mailer to mailers sidekiq queue d4d52734072382159b0c4249fe76c104c1c3f9cd
- Update openssl to 1.0.1q f99fd257a6aa541662095fb72ce8af802c59c3a0
- Added support for GitLab Pages aef69fe5fccbd14c9c0112bae58d5ecaa6e680bd
- Updated Mattermost to v1.3.0 53d8606cf3642949ced4d6e8432d4b45b0541c88

8.2.3

- Add gitlab_default_projects_features_builds variable (Patrice Bouillet) e13556d33772c2d6b084d358ff67ea7da2c78a91

8.2.2

- Set client_max_body_size back to all required blocks 40047e09192686a739e2b7e52133885d192dab7c
- Specific replication entry in pg_hba.conf for Postgresql replication 7e32b1f96aaebe810d320ade965244fc2352314e

8.2.1

- Expose artifacs configuration options 4aca77a5ae78a836cc9f3be060afacc3c4e72a28
- Display deploy page on all pages b362ee7d70851c291ff0d090fd75ef550c5c5baa

8.2.0

- Skip builds directory backup in preinstall 1bfbf440866e0834f133e305f7659df1ee1c9e8a
- GitLab Mattermost version 1.2.1, few default settings changed 34a3a366eb9b6e5deb8117bcf4430659c0fb7ecc
- Refactor mailroom into a separate service 959c1b3f437d49eb1a173dea5d6d5ca3d79cd098
- Update nginx config for artifacts and lfs 4e365f159e3c70aa1aa3a578bb7440e27fcdc179
- Added lfs config settings 4e365f159e3c70aa1aa3a578bb7440e27fcdc179
- Rename gitlab-git-http-server to gitlab-workhorse 47afb19142fcb68d5c35645a1efa637f367e6f84
- Updated chef version to 12.5.1 (Jayesh Mistry) 814263c9ecdd3e6a95148dfdb15867468ef43c7e
- gitlab-workhorse version 0.4.2 3b66c9be19e5718d3e92df3a32df4edaea0d85c2
- Fix docker image pushing when package is RC 99bad0cf400460ade2b2360a1e4e19605539a6c9

8.1.3

- Update cacerts to 2015.10.28 e349060c81b75f9543ececec14f5c9c721c91d50

8.1.2

- Load the sysctl config as soon as it is set a9f5ece8e7f08a23ceb792e919c941d01d3e14b7
- Added postgresql replication settings f1949604de8017355c26710205156a0147ffa793

8.1.1

- Fix missing email feedback address for Mattermost (Pete Deffendol) 4121e5853a00ed882a6eb97a40fc274f05d3b68c
- Fix reply by email support in the package 49cc150360028d62d8d64c6416fad78d474a5933
- Add mailroom to the log 01e26d3412a4e2fac7411874bc81a20a27123921
- Fix sysctl param loading da0c487ff8518f0989052a53d397a7cb669acb35

8.1.0

- Restart gitlab-git-http-server on version change
- Moved docker build to omnibus-gitlab repository 9757575747c9d78e355ecd76b11dd7b9dc4d94b5
- Using sv to check for service status e7b00e4a5d8f0195d9a3f59a6d398a6d0dba3773
- Set kernel.sem for postgres connections dff749b36a929f9a7dfc128b60f3d53cf2464ed8
- Use ruby 2.1.7 6fb46c4db9e5daf8a724f5c389b56ea8d918b36e
- Add backup encription option for AWS backups 8562644f3dfe44b6faed35f8e0769a0b7c202569
- Update git to 2.6.1 b379c1060a6af314209b86161ea44c8467c5a49f
- Update gitlab-git-http-server to 0.3.0 737815fd22a71f1b94379a1a11d8b82367cc7b3a
- Move incoming email settings to gitlab.yml 9d8673e221ad869199d633c7feccab167a64df6d
- Add config to enable slow query logging e3c4013d4c01ec372962b1310f17af5ded963ea4
- GitLab Mattermost to 1.1.1 38ef5d7b609c190502d48374cc2b88cbe0caa307
- Do not try to stop ci services if they are already disabled 635d7952fad2d501a8f1a38a9e977c4297ce2e52

8.0.4

- Fix accidental removal of creating backup directory cb7afb0dff528b8e7f3e8c54801e3635576e33a7
- Create secrets and database templates for gitlab-ci for users upgrading from versions prior to 7.14 b9df5e8ce58b818c3b0650ab4d99c883bead3991
- Change the ownership of gitlab-shell/hooks directory a6fe61e7e1f54c1eadce78072ba902388db5453f

8.0.3

- Update gitlab-git-http-server to 0.2.10 76ea52321be798329e5ece9f4b935bb1f2b579ad
- Switch to chef-gem 6b15effce70a41c0041e0bca8b80d72c02be1fcf

8.0.2

- If using external mysql for mattermost don't run postgres code d847479b8bcb523110aae9230bcf480def3eab15
- Add incoming_email_start_tls config ec02a9076f1c59dbd9a85cbfd8b164f56a8c4da7

8.0.1

- Revert "Do not buffer with nginx git http requests"

8.0.0

- gitlab-git-http-server 0.2.9 is enabled by default e6fa1b77c9501da6b6ef44c92e2705b1e94166ea
- Added reply by email configuration 3181425e05bd7be76832957367a24df771bdc84c
- Add to host to ssh config for git user for bitbucket importer 3b0f7ebefcb9221b4ed97f234f9e728e3faf0b7d
- Add ability to configure the format of nginx logs 03511afa1d3440459b327bd873550c3cc6a6a44e
- Add option to configure db driver for Mattermost f8f00ff20304753b3eeef5d004930c4a8c404e1c
- Remove local_mode_cache_warning warnings durning reconfigure run 6cd30475cde59803f2d6f9ff8e00bde520512113
- Update chef server version to 12.4.1 435183d75f4d2c8333923e95fc6254c52901295f
- Enable spdy support when using ssl (Manuel Gutierrez) caafd1d9cf86ccecfc1f7ecddd3fd005727beddd
- Explicitly set scheme for X-Forwarded-Proto (Stan Hu) 19d71ac3cbd086f25a2e4ce284ea341d96b7ec46
- Add option to set ssl_client_certificate path (Brayden Lopez) fc0f7e9344a80ff882f4247049668ac1636e4229
- Add new Kerberos configuration settings for EE 40fc4a8687e649b0b662014dfa61442aaf4bd437
- Add proxy_read_timeout and proxy_connect_timeout config (Alexey Zalesnyi) 286695fd91bef6d784e21e80bf20d406440176b4
- Add option to disable accounts management through omnibus-gitlab b7f5f2bea422f190dd260eb555cbf4c6c7e1b351
- Change the way sysctl configuration is being invoked 5481024558c4881d7c30942419358e12a0340673
- Fix redirect ports in nginx templates 54e342cd8dc6315bcabafc4efb81be108c78b5ee
- Do not buffer with nginx git http requests 99ea9025a48427f1cbfeafe3a577c88d7dd7817d

7.14.3

- Add redis password option when using TCP auth d847479b8bcb523110aae9230bcf480def3eab15

7.14.2

- Update gitlab-git-http-server to version 0.2.9 82a3bec2eb3f006bb9327a59608f99cae81d5c92
- Ignore unknown values from gitlab-secrets.json (Stan Hu) ef76c81d7b71f72d6438e3458d61ecaef8965e17
- Update cacerts to 2015.09.02 6bb15558b681035e0db75e41f5a14cc878344c9d

7.14.1

- Update gitlab-git-http-server to version 0.2.8 505de5318f8e464f88e7a57e65d76387ef86cfe5
- Fix automatic SSO authorization between GitLab and Mattermost (Hiroyuki Sato) 1e7453bb71b92ba0fb095fc9ebab25015451b6bc

7.14.0

- Add gitlab-git-http-server (disabled by default) 009aa7d2e68bc84717fd363c88e655ee510aa8e5
- Resolved intermittent issues in gitlab-ctl reconfigure 83ce5ac3fe50acf3da1da572cd8b88016039f1a0
- Added backup_archive_permissions configuration option fdf9a793d533c0b3ca19295746ba6cba33b1af7a
- Refactor gitlab-ctl stop for unicorn and logrotate b692b824454681c6a204f627b9be72d6fcf7838d
- Include GitLab Mattermost in the package 7a6f6012b8c3a8e187bd6213278e5b37d533d228

7.13.2

- Move config.ru out of etc directory to prevent passenger problems 5ee0ac221485ce0e385f4999838f319ba65755ed
- Fix merge gone wrong to include upgrade to redis 2.8.21 528400090ed82ff212f08c4402c0b4681f91dc2e

7.13.1

- No changes

7.13.0

- IMPORTANT: Default number of unicorn workers is at minimum 2, maximum number is calculated to leave 1GB of RAM free 2f623a5e9b6d8c64b9ac30cd656a4e852895fcf0
- IMPORTANT: Postgresql unix socket is now moved from Postgresql default to prevent clashes between packaged and (possibly) existing Postgresql installation 9ca63f517d1bc6876abe90738e1fd99ea6f17ef6
- Packages will be built with new tags b81165d93422a8cb7ed80b0f33107bba636b094f
- Unicorn worker restart memory range is now configurable 69e0f8f2412509bead62944c6cd891a57926303a
- Updated redis to 2.8.21 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated omnibus-ctl to 0.3.6 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated chef to 12.4.0.rc.2 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated nginx to 1.7.12 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated libxml2 to 2.9.2 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated postgresql to 9.2.10 d1f2f38da7381507624e18fcb77e489dff1d988b
- Updated omnibus to commit 0abab93bb67377d20c94bc4322018e2248b4a610 d1f2f38da7381507624e18fcb77e489dff1d988b
- Postinstall message will check if instance is on EC2. Improved message output. dba7d1ed2ad06c6830b2f51d0d2090e2fc1d1490
- Change systemd service so GitLab starts up only after all FS are mounted and services started 2fc8482dafed474cb508b67ef17e982e3a30bdd1
- Use posttrans scriplet for RHEL systems to run upgrade or symlink omnibus-gitlab commands f9169ba540ae82017680d3bb313ecc1f5dc3567d
- Set net.core.somaxconn parameter for unicorn f147911fd0f9ddb4b55c26010bcedca1705c1b0b
- Add configuration option for builds directory for GitLab CI a9bb2580db4f9aabf086d25122d30aeb78e2f756
- Skip running selinux module load if selinux is disabled 5707ef1d25ff3ea202ce88d444154b5c5a6a9158

7.12.2

- Fix gitlab_shell_secret symlink which was removed by previous package on Redhat platform systems b34d4bcf4fae9581d94bdc5ed104a4655b72f4ad
- Upgrade openssl to 1.0.1p 0ebb908e130d191c3fa7e98b0a16f1e303d50890

7.12.1

- Added configuration options for auto_link_ldap_user and auto_sign_in_with_provider fdb185c14fa8fd7e57fddb41b62ce15ae4544380
- Update remote_syslog to 1.6.15 a1b3772ad32a3989b172aea175e7850609deb6e2
- Fixed callback url for CI autoauthorization dbb46b073d70aec5385efd056cfa45e39fbce764

7.12.0

- Allow install_dir to be changed to allow different build paths (DJ Mountney) d205dc9e4da86ea39af18a6715f9538d3893488cf
- Switched to omnibus fork 99c713cb579e8371a334b4e43a7d7863794d8374
- Upgraded chef to 12.4.0.rc.0 b1a3870bd5a5bc60335655a4965f8f80a9be939f
- Remove generated gitlab_shell_secret file during build 8ba8e9221516a0235f565bc5560bd0cec9c3c48e
- Update redis to 2.8.20 6589e23ed79c883988e0ebefc356699f5f94228f
- Exit on package installation if backup failed and wasn't skipped 710253c318a029bf1bb158c6c9fc81f0f695fe34
- Added sslmode and sslrootcert database configuration option (Anthony Brodard) dbeb00346ccafdda50e52cf601c6b457b5981b74
- Added option to disable HTTPS on nginx to support proxied SSL for GitLab CI
- Added custom listen_port for GitLab CI nginx to support reverse proxies
- IMPORTANT: secret_token in gitlab.rb for GitLab, GitLab-shell and GitLab CI will now take presedence over the auto generated one
- Automatically authorise GitLab CI with GitLab when they are on the same server
- Transmit gitlab-shell logs with remote_syslog 9242b83525cc18df22d1f44fb002a67e94b4ad5c
- Moved GitLab CI cronjob from root to the gitlab-ci user 4b9926b8c016c2c10f8511a5b083f6d5a7071041
- gitlab-rake and gitlab-ci-rake can be ran without sudo 4d4e3702ffee890eabed1d4cb61dd351baf2b554
- Git username and email are removed from git users gitconfig 1911109c0679f90e5184415c52ad5da4e31b7171
- Updated openssl to 1.0.1o 163305cac9ecd37425c3b1e10a390176a753717c
- Updated git version to 2.4.3 88186e3e71064c0d9e7ae674c5f68450226dfa68
- Updated SSL ciphers to exclude all DHE suites 08f790400b31eb3fbf4ce0ee736f7cc9082b28fc
- Updated rubygems version to 2.2.5 c85aed400bd8e17c5e919d19cd93c08616190e0b
- Rewrite runit default recipe which will now decide differently on which init is used  d3156878eadd643f136ee49d233e6c0b4ccebb28
- Do not depend on Ohai platform helper for running selinux recipe cee73a23488f61fd5a0c2b090a8e86ca5209cd3c

7.11.0

- Set the default certificate authority bundle to the embedded copy (Stan Hu) 673ac210216b9c01d58196e826b98db780a4ccd5
- Use a different mirror for libossp-uuid (DJ Mountney) 7f46d70855a4d97eb2b833fc2d120ddfc514dfd4
- Update omnibus-software 42839a91c297b9c637a13fbe4beb05058672abe2
- Add option to disable gitlab-rails when using only CI a784851e268ca1f23ce817c13a8d421c3211f96a
- Point to different state file for gitlab logrotate 42591805f64c48cb845538012b2a43fe765637d2
- Allow setting ssl_dhparam in nginx config 7b0c80ed9c1d85bebeedfc211a9b9e395593278c

7.10.0

- Add option to disable HTTPS on nginx to support proxied SSL (Stan Hu) 80f4204052ceb3d47a0fdde2e006e79c099e5237
- Add openssh as runtime dependency e9b4f537a67ea6a060d8a974d3fc56f927a218b2
- Upgrade chef-gem version to 11.18.0 5a5300fe6b43c3ce11b796bb0ffc9fe62c731b1b
- Upgrade gitlab-ctl version to 0.3.3 cdcbb3b4bc299ef264633188570228d886d1a5c4
- Specify build directory for pip for docutils build a0e240c9693ebd8ec272282d37626f12dfee5da5
- Upgrade ruby to 2.1.6 5058dd591df5bcea08b98ed365eb29f955715ea6
- Add archive_repo sidekiq queue 3ed5e6e162794f4dc173a5e801dab975be6f61a2
- Add CI services to remote syslog 5fa5235aef0b8b119b3deb1ab1274a9e72ac6a2d
- Set number of unicorn workers to CPU core count + 1 5ad7e8b89c10417d8663520ecc43432bf3d8a0db
- Upgrade omnibusy-ruby to 4.0.0 d8d6a20551cd8376e2cfc05b53487911da7aa7b1
- Upgrade postgresql version to 9.2.9  d8d6a20551cd8376e2cfc05b53487911da7aa7b1
- Upgrade nginx to 1.7.11 528658852f9f5a1cc75a80ea86f48f92b75d54a3
- Upgrade zlib to 1.2.8 20ed5ce4d0a6eb5326319761fc7fd53dbcebb620
- Create database using the database name in attributes c5dfbe87869f85f45d6df16b1ebd3f4967fc7eb0
- Add gitlab_email_reply_to property (Stan Hu) e34317a289ae2a904c981b1ff6db7c4098571835
- Add configuration option for gitlab-www user home dir e975b3ab47a4ccb795da4721ef32b54340434354
- Restart nginx instead of issuing a HUP signal changes so that changes in listen_address work (Stan Hu) 72d09b9b29a1a974e35aa6088912b6a6c4d7e4ac
- Automatically stop GitLab, backup, reconfigure and start after a new package is installed
- Rename the package from 'gitlab' to 'gitlab-ce' / 'gitlab-ee'
- Update cacerts version e57085281e9f4d3ae15d4f2e14a88b3399cb4df3
- Better parsing of DB settings in gitlab.rb 503fad5f9d0a4653d8540331f77f487a7b51ce3d
- Update omnibus-ctl version to 0.3.4 b5972560c801bc22658d459ad00fa4f33a6c34d2
- Try to detect init system in use on Debian (nextime) 7dd0234c19616e1cbe0656e55ef8a53be3fe882b
- Devuan support added in runit (nextime) 7dd0234c19616e1cbe0656e55ef8a53be3fe882b
- Disable EC2 plugin 70ba5285e1e89ababf25c9cb9ac817bb582f5a43
- Disable multiple ohai plugins 0026ba26757a2b7168e7de86ab0652c0aec62ddf

7.9.0

- Respect gitlab_email_enabled property (Daniel Serodio) e2982692d49772c4f896a775e476a62b4831b8a1
- Use correct cert for CI (Flávio J. Saraiva) 484227e2dfe33f59e3683a5757be6842d7ce79d2
- Add ca_path and ca_file params for smtp email configuration (Thireus) fa9c1464bc1eb173660edfded1a2f7add7ac24b3
- Add custom listen_port to nginx config for reverse proxies (Stan Hu) 8c438a68fb155bd3489c32a1478484ccfd9b3ffb
- Update openssl to 1.0.1k 0aa00aecf0867e5d454ebf089cb3a23d4645632c
- DEPRECATION: 'gitlab_signup_enabled', 'gitlab_signin_enabled', 'gitlab_default_projects_limit', 'gravatar_enabled' are deprecated, settings can be changed in admin section of GitLab UI
- DEPRECATION: CI setting `gitlab_ci_add_committer` is deprecated. Use `gitlab_ci_add_pusher` to notify user who pushed the commit of a failing build
- DEPRECATION: 'issues_tracker_redmine', 'issues_tracker_jira' and related settings are deprecated. Configuring external issues tracker has been moved to Project Services section of GitLab UI
- Change default number of unicorn workers from 2 to 3 3d3f6e632b61326f6ff0376d7151cf7cf945383b
- Use systemd for debian 8 6f8a9e2c8258de883a437d1b8104d69726a18bdd
- Increase unicorn timeout to 1 hour f21dddc2d2e20c7a7d3376dc2839fff2629ec406
- Add nodejs dependency
- Added option to add keys needed for bitbucket importer c8c720f97098774679bca2c1d1200e2a8126827f
- Add rack attack and email_display name config options e3dcc9a7efcec9b4ddf7e715fed9da7ac971cc57

7.8.0

- Add gitlab-ci to logrotate (François Conil) 397ce5bab202d9d86e30a62538dca1323b7f6f4c
- New LDAP defaults, port and method 7a65245c59fd094e88784f924ecd968d134716fa
- Disable GCE plugin 35b7b89c78fe7e1c35bb7063c2a03e70d6915c1d

7.7.0

- Update ruby to 2.1.5 79e6833045e70a43ac66f65252d40773c20438df
- Change the root_password setting to initial_root_password 577a4b7b895e17cbe159bf317169d173c6d3567a
- Include CI Oauth settings option 2e5ae7414ecd9f73cbfe284af5d38ee65ac892e4
- Include option to set global git config options 8eae0942ec27ffeec534ba02e4171a3b6cd6d193

7.6.0
- Update git to 2.0.5 0749ffc43b4583fae6fc8ac1b91111340a225f92
- Update libgit2 and rugged to version 0.21.2 66ac2e805a166ecb10bdf8ba001b106acd7e49f3
- Generate SMTP settings using one template for both applications (Michael Ruoss) a6d6ff11f102c6fa9da6209f80162c5e137feeb9
- Add gitlab-shell configuration settings for http_settings, audit_usernames, log_level 5e4310442a608c5c420ffe670a9ab6f111489151
- Enable Sidekiq MemoryKiller by default with a 1,000,000 kB limit 99bbe20b8f0968c4e3c4a42281014db3d3635a7f
- Change runit recipe for Fedora to systemd (Nathan) fbb7687f3cc2f38faaf6609d1396b76d2f6f7507
- Added kerberos lib to support gitlab dependency 66fd3a85cce74754e850034894a87d554fdb04b7
- gitlab.rb now lists all available configuration options 6080f125697f9fe7113af1dc80e0a7bc9ddb284e
- Add option to insert configuration settings in nginx template (Sander Boom) 5ba0485a489549a0bb33531e027a206b1775b3c0


7.5.0
- Use system UIDs and GIDs when creating accounts (Tim Bishop) cfc04342129a4c4dca5c4827d541c8888adadad3
- Bundle GitLab CI with the package 3715204d86900e8501483f70c6370ba4e3f2bb3d
- Fix inserting external_url in gitlab.rb after installation 59f5976562ce3439fb3a6e43caac489a5c230db4
- Avoid duplicate sidekiq log entries on remote syslog servers cb514282f03add2fa87427e4601438653882fa03
- Update nginx config and SSL ciphers (Ben Bodenmiller) 0722d29c 89afa691
- Remove duplicate http headers (Phill Campbell) 8ea0d201c32527f095d3afa707a38865984e27d2
- Parallelize bundle install during build c53e92b80f423c90f2169fbd2d9ef33ce0233cb6
- Use Ruby 2.1.4 e083162579f00814086f34c1cf02c96dc9796f69
- Remove exec symlinks after gitlab uninstall 70c9a6e00be8814b8cad337b1e6d212be88a3f99
- Generate required gitlab_shell_secret d65d4832f1164dfe62036a65d1899ccf80cbe0c6

7.4.0
- Fix broken environment variable removal
- Hard-code the environment directory for gitlab-rails
- Set PATH and RAILS_ENV via the env directory
- Set the environment for gitlab-rails and gitlab-rake via chpst
- Configure bundle exec wrapper with gitlab-rails-rc
- Add a logrotate service for `gitlab-rails/production.log` etc.
- Again using backwards compatible ssl ciphers
- Increased Unicorn timeout to 60s
- For non-bundled webserver added an option of supplying external webserver user username
- Add option for using backup uploader
- Update openssl to 1.0.1j
- If hostname is correctly set, omnibus will prefill external_url

7.3.1
- Fix web-server recipe order
- Make /var/opt/gitlab/nginx gitlab-www's home dir
- Remove unneeded write privileges from gitlab-www

7.3.0
- Add systemd support for Centos 7
- Add a Centos 7 SELinux module for ssh-keygen permissions
- Log `rake db:migrate` output in /tmp
- Support `issue_closing_pattern` via gitlab.rb (Michael Hill)
- Use SIGHUP for zero-downtime NGINX configuration changes
- Give NGINX its own working directory
- Use the default NGINX directory layout
- Raise the default Unicorn socket backlog to 1024 (upstream default)
- Connect to Redis via sockets by default
- Set Sidekiq shutdown timeout to 4 seconds
- Add the ability to insert custom NGINX settings into the gitlab server block
- Change the owner of gitlab-rails/public back to root:root
- Restart Redis and PostgreSQL immediately after configuration changes
- Perform chown 7.2.x security fix in postinst

7.2.0
- Pass environment variables to Unicorn and Sidekiq (Chris Portman)
- Add openssl_verify_mode to SMTP email configuration (Dionysius Marquis)
- Enable the 'ssh_host' field in gitlab.yml (Florent Baldino)
- Create git's home directory if necessary
- Update openssl to 1.0.1i
- Fix missing sidekiq.log in the GitLab admin interface
- Defer more gitlab.yml defaults to upstream
- Allow more than one NGINX listen address
- Enable NGINX SSL session caching by default
- Update omnibus-ruby to 3.2.1
- Add rugged and libgit2 as dependencies at the omnibus level
- Remove outdated Vagrantfile

7.1.0
- Build: explicitly use .forward for sending notifications
- Fix MySQL build for Ubuntu 14.04
- Built-in UDP log shipping (Enterprise Edition only)
- Trigger Unicorn/Sidekiq restart during version change
- Recursively set the SELinux type of ~git/.ssh
- Add support for the LDAP admin_group attribute (GitLab EE)
- Fix TLS issue in SMTP email configuration (provides new attribute tls) (Ricardo Langner)
- Support external Redis instances (sponsored by O'Reilly Media)
- Only reject SMTP attributes which are nil
- Support changing the 'restricted_visibility_levels' option (Javier Palomo)
- Only start omnibus-gitlab services after a given filesystem is mounted
- Support the repository_downloads_path setting in gitlab.yml
- Use Ruby 2.1.2
- Pin down chef-gem's ohai dependency to 7.0.4
- Raise the default maximum Git output to 20 MB

7.0.0-ee.omnibus.1
- Fix MySQL build for Ubuntu 14.04

7.0.0
- Specify numeric user / group identifiers
- Support AWS S3 attachment storage
- Send application email via SMTP
- Support changing the name of the "git" user / group (Michael Fenn)
- Configure omniauth in gitlab.yml
- Expose more fields under 'extra' in gitlab.yml
- Zero-downtime Unicorn restarts
- Support changing the 'signin_enabled' option (Konstantinos Paliouras)
- Fix Nginx HTTP-to-HTTPS log configuration error (Konstantinos Paliouras)
- Create the authorized-keys.lock file for gitlab-shell 1.9.4
- Include Python and docutils for reStructuredText support
- Update Ruby to version 2.1.1
- Update Git to version 2.0.0
- Make Runit log rotation configurable
- Change default Runit log rotation from 10x1MB to 30x24h
- Security: Restrict redis and postgresql log directory permissions to 0700
- Add a 'gitlab-ctl deploy-page' command
- Automatically create /etc/gitlab/gitlab.rb after the package is installed
- Security: Use sockets and peer authentication for Postgres
- Avoid empty Piwik or Google Analytics settings
- Respect custom Unicorn port setting in gitlab-shell

6.9.4-ee.omnibus.1
- Security: Use sockets and peer authentication for Postgres

6.9.2.omnibus.2
- Security: Use sockets and peer authentication for Postgres

6.9.2
- Create the authorized-keys.lock file for gitlab-shell 1.9.4

6.9.1
- Fix Nginx HTTP-to-HTTPS log configuration error (Konstantinos Paliouras)

6.9.0
- Make SSH port in clone URLs configurable (Julien Pivotto)
- Fix default Postgres port for non-packaged DBMS (Drew Blessing)
- Add migration instructions coming from an existing GitLab installation (Goni Zahavy)
- Add a gitlab.yml conversion support script
- Correct default gravatar configuration (#112) (Julien Pivotto)
- Update Ruby to 2.0.0p451
- Fix name clash between release.sh and `make release`
- Fix Git CRLF bug
- Enable the 'sign_in_text' field in gitlab.yml (Mike Nestor)
- Use more fancy SSL ciphers for Nginx
- Use sane LDAP defaults
- Clear the Rails cache after modifying gitlab.yml
- Only run `rake db:migrate` when the gitlab-rails version has changed
- Ability to change the Redis port

6.8.1
- Use gitlab-rails 6.8.1

6.8.0
- MySQL client support (EE only)
- Update to omnibus-ruby 3.0
- Update omnibus-software (e.g. Postgres to 9.2.8)
- Email notifications in release.sh
- Rewrite parts of release.sh as a Makefile
- HTTPS support (Chuck Schweizer)
- Specify the Nginx bind address (Marco Wessel)
- Debian 7 build instructions (Kay Strobach)

6.7.3-ee.omnibus.1
- Update gitlab-rails to v6.7.3-ee

6.7.3-ee.omnibus

6.7.4.omnibus
- Update gitlab-rails to v6.7.4

6.7.2-ee.omnibus.2
- Update OpenSSL to 1.0.1g to address CVE-2014-0160

6.7.3.omnibus.3
- Update OpenSSL to 1.0.1g to address CVE-2014-0160
