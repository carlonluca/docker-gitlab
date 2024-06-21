<!--
Merging into stable branches in canonical projects is reserved for
GitLab patch releases https://docs.gitlab.com/ee/policy/maintenance.html#patch-releases

If you're backporting a security fix, please refer to the security merge request
template https://gitlab.com/gitlab-org/omnibus-gitlab/-/blob/master/.gitlab/merge_request_templates/Security%20Release.md
Security backport merge requests should not be opened on the Omnibus GitLab canonical project.
-->

## What does this MR do and why?

_Describe in detail what merge request is being backported and why_

## MR acceptance checklist

This checklist encourages us to confirm any changes have been analyzed to reduce risks in quality, performance, reliability, security, and maintainability.

* [ ] This MR is backporting a bug fix, documentation update, or spec fix, previously merged in the default branch.
* [ ] The original MR has been deployed to GitLab.com (not applicable for documentation or spec changes).
* [ ] This MR has a [severity label] assigned (if applicable).

#### Note to the merge request author and maintainer

The process of backporting bug fixes into stable branches is tracked as part of an
[internal pilot]. If you have questions about this process, please:

* Refer to the [internal pilot] issue for feedback or questions.
* Refer to the [patch release runbook for engineers and maintainers] for guidance.

[severity label]: https://handbook.gitlab.com/handbook/engineering/infrastructure/engineering-productivity/issue-triage/#severity
[internal pilot]: https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/2886
[patch release runbook for engineers and maintainers]: https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/patch/process_new.md

/assign me
