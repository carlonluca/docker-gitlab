These are the contributing guidelines for omnibus-gitlab issues and merge
requests.

## General issue guidelines

If you are experiencing problems during GitLab package installation or have issues with package configuration please create an issue that includes the following:

- Include the omnibus-gitlab version when discussing behavior: `dpkg-query -W
  gitlab` or `rpm -q gitlab`.
- Include the omnibus-gitlab configuration: `sudo gitlab-ctl show-config`
- Copy few lines before, full error output and few lines after from the `gitlab-ctl reconfigure` run log and paste it inside a [GitLab snippet](https://gitlab.com/snippets) or inside the issue description under triple backticks "```".

*Warning* Be careful when pasting log outputs of `gitlab-ctl reconfigure` or `gitlab-ctl show-config`; They will contain secrets like passwords and keys so *make sure to edit out all secrets before pasting the log output*.

#### For problems not related to package installation and configuration check ways to get help [at GitLab website.](https://about.gitlab.com/getting-help/)

This can be the case when installation and `gitlab-ctl reconfigure` run went without issues but your GitLab instance is still giving 500 error page with an error in the log.

## Maintainer documentation

### Issue description templates

Issue description template will show this message to
all users that create issues in this repository:

```
When submitting an issue that is not a feature request, please submit the following:

1. Make sure that the issue is with the package itself. If your GitLab is running but you are seeing error page 500, first check https://about.gitlab.com/getting-help/ on where to ask your question
1. Include the omnibus-gitlab package version with: dpkg-query -W
gitlab or rpm -q gitlab
1. Relevant sections of `/etc/gitlab/gitlab.rb` (make sure to omit any sections that start with # and passwords)
1. Whether the problems are caused on a fresh install or an upgrade(Describe the upgrade history)
1. Describe the OS and the system environment GitLab is installed on (Is it a clean VM, is anything else running on it, etc.)
```

### Issue response template

When the maintainer suspects the reported issue is not related to the problems with omnibus-gitlab, following template can be used to respond to the issue reporter:

```

Thanks for reporting this issue. I suspect that the issue you are experiencing is not related to the package or configuration of the package itself. Omnibus-gitlab repository is used for packaging GitLab. Since this looks like a problem not related to the packaging please check
[how to get help](https://about.gitlab.com/getting-help/) for your issue. I will close this issue but if you still think this is a problem with the package please @ mention me with the steps to reproduce the problem and I will reopen the issue.

```

### Closing issues

If an issue has a `Awaiting Feedback` label and the response from the reporter
has not been received for 14 days, we can close the issue using the following
response template:

```
We haven't received an update for more than 14 days so we will assume that the
problem is fixed or is no longer valid. If you still experience the same problem
try upgrading to the latest version. If the issue persists, reopen this issue
with the relevant information.
```

## Developer Guidelines

### Setting up development environment

Check [setting up development environment docs](doc/development/README.md) for
instructions on setting up a environment for local development.

### Writing tests

Any change in the internal cookbook also requires specs. Apart from testing the
specific feature/bug, it would be greatly appreciated if the submitted Merge
Request includes more tests. This is to ensure that the test coverage grows with
development.

When in rush to fix something (eg. security issue, bug blocking the release),
writing specs can be skipped. However, an issue to implement the tests 
**must be** created and assigned to the person who originally wrote the code.

### Merge Request Guidelines

If you are working on a new feature or an issue which doesn't have an entry on
Omnibus GitLab's issue tracker, it is always a better idea to create an issue
and mention that you will be working on it as this will help to prevent
duplication of work. Also, others may be able to provide input regarding the
issue, which can help you in your task.

It is preferred to make your changes in a branch named \<issue
number>-\<description> so that merging the request will automatically close the
specified issue.

A good Merge Request is expected to have the following components, based on
their applicability:

 1. Full Merge Request description explaining why this change was needed
 2. Code for implementing feature/bugfix
 3. Tests, as explained in [Writing Tests](#writing-tests)
 4. Documentation explaining the change
 5. If Merge Request introduces change in user facing configuration, update to [gitlab.rb template](files/gitlab-config-template/gitlab.rb.template)
 6. Changelog entry to inform about the change, if necessary.
