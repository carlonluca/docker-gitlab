---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Changing `gitlab.yml` and `application.yml` settings

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** Self-managed

Some GitLab features can be customized through
[`gitlab.yml`](https://gitlab.com/gitlab-org/gitlab-foss/blob/master/config/gitlab.yml.example). If you want to change a `gitlab.yml` setting
for a Linux package installation, you need to do so with `/etc/gitlab/gitlab.rb`. The
translation works as follows. For a complete list of available options, visit the
[`gitlab.rb.template`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template).
New installations starting from GitLab 7.6 have
all the options of the template listed in `/etc/gitlab/gitlab.rb` by default.

In `gitlab.yml`, you find structure like this:

```yaml
production: &base
  gitlab:
    default_theme: 2
```

In `gitlab.rb`, this translates to:

```ruby
gitlab_rails['gitlab_default_theme'] = 2
```

What happens here is that we forget about `production: &base`, and join
`gitlab:` with `default_theme:` into `gitlab_default_theme`.
Note that not all `gitlab.yml` settings can be changed via `gitlab.rb` yet; see
the [`gitlab.yml.erb` template](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-cookbooks/gitlab/templates/default/gitlab.yml.erb).
If you think an attribute is missing please create a merge request on the `omnibus-gitlab` repository.

Run `sudo gitlab-ctl reconfigure` for changes in `gitlab.rb` to take effect.

Do not edit the generated file in `/var/opt/gitlab/gitlab-rails/etc/gitlab.yml`
because it is overwritten on the next `gitlab-ctl reconfigure` run.

## Adding a new setting to `gitlab.yml`

First, consider not adding a setting to `gitlab.yml`. See **Settings** under [GitLab-specific concerns](https://docs.gitlab.com/ee/development/code_review.html#gitlab-specific-concerns).

Don't forget to update the following 5 files when adding a new setting:

- the [`gitlab.rb.template`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)
  file to expose the setting to the end user via `/etc/gitlab/gitlab.rb`.
- the [`default.rb`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-cookbooks/gitlab/attributes/default.rb)
  file to provide a sane default for the new setting.
- the [`gitlab.yml.example`](https://gitlab.com/gitlab-org/gitlab/blob/master/config/gitlab.yml.example)
  file to actually use the setting's value from `gitlab.rb`.
- the [`gitlab.yml.erb`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-cookbooks/gitlab/templates/default/gitlab.yml.erb)
  file
- the [`gitlab-rails_spec.rb`](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/spec/chef/cookbooks/gitlab/recipes/gitlab-rails_spec.rb)
  file
