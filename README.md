# Apps

This repository contains application definitions to be deployed on EKS using
ArgoCD.

This document covers the overall structure of the repository and how to add a
new application. For more detailed guidance see our documentation on
[the Internal Developer Platform wki](https://github.com/jppol-idp/internal-developer-platform/wiki/IDP-documentation).

## Structure

This repository contains several directories, each representing a different
environment and containing the applications to be deployed in that environment.

The directory structure is as follows:

```
apps/
  {team}-dev/
    app1/
      application.yaml
      values.yaml
    app2/
      application.yaml
      values.yaml
    ...
  {team}-test/
    app1/
      application.yaml
      values.yaml
    app2/
      application.yaml
      values.yaml
    ...
  {team}-prod/
    app1/
      application.yaml
      values.yaml
    app2/
      application.yaml
      values.yaml
    ...
```

## Adding a new application

Adding a new application requires specifying an `application.yaml` and
`values.yaml` file in the relevant environment directories corresponding to
where you application should be deployed.

You can do this either by using the scaffolding tool
[Copier](https://copier.readthedocs.io/en/stable/#installation) or by manually
creating the files.

### Using Copier

To use Copier, first
[follow the steps on the Copier documentation to install it](https://copier.readthedocs.io/en/stable/#installation).

Then, run the following command to initialize a new application:

```bash
copier copy https://github.com/jppol-idp/apps-scaffold .
```

This will prompt you for the name of your application and create the required
files for the chosen environments.

Go through any TODOs in the `values.yaml` files and fill in the required values.
You can simply search for `TODO` in the file to find them.

Commit and push your changes and the application will be tracked by ArgoCD. This
is covered in
[seeing your deployment in ArgoCD](#seeing-your-deployment-in-argocd).

### Seeing your deployment in ArgoCD

To see your deployment in ArgoCD, navigate to the ArgoCD UI hosted at
`argocd.<cluster-name>.idp.jppol.dk`. This url will vary depending on your
environment. In here you should see your application listed and you can click on
it to see the details, including the individual tracked resources.

If your application is hosted on the public internet you can also navigate to
its URL to see it running.

### Monitoring your application

We use Grafana for monitoring our of our applications. You can access Grafana at
`grafana.<cluster-name>.idp.jppol.dk`.
