## AI team IDP POC onboarding

### Introduction
To ensure a seamless onboarding experience, this guide covers the necessary steps for gaining access to our Kubernetes cluster using kubectl, ArgoCD, and Grafana.

### Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed locally.
- [AWS](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) CLI installed locally.
- A Github account which is a member of the GitHub organization **jppol-idp**
- An AWS SSO account with access to the account **970547334392** with permission-set **idp-ai-team**

### Recommended but optional tools
- [kubectx](https://github.com/ahmetb/kubectx) - which provides easy switching between kubernetes contexts and namespaces.
- [kubecolor](https://github.com/kubecolor/kubecolor) - adds color to your kubectl output.
- [K9s](https://k9scli.io/) - an interactive terminal-based UI for Kubernetes clusters.
- [aws-vault](https://github.com/99designs/aws-vault) - A tool to securely manage temporary AWS credentials

### Step 1: Configure AWS CLI
We will be using temporary AWS credentials, so we need to configure the AWS CLI with these credentials.
Go to [AWS SSO](https://jppol-sso.awsapps.com/start) and sign in with your JP-Pol SSO account. Once signed in, you should see a list of AWS accounts. Select the account: **aws-kaspers-test@jppol.dk** and the Access Keys for role: **idp-ai-team** and follow the instructions to get temporary credentials.
Export these credentials in your terminal and set your region which in this case is **eu-north-1** (Stockholm)
```
$ export AWS_ACCESS_KEY_ID=<your-access-key-id>
$ export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
$ export AWS_SESSION_TOKEN=<your-session-token
$ export AWS_REGION=eu-north-1
```
Please run the following command to make sure that your AWS CLI is configured correctly
```
$ aws sts get-caller-identity
{
    "UserId": "AROA6D6JBBT4HHGZ65KUR:<user-account>",
    "Account": "970547334392",
    "Arn": "arn:aws:sts::970547334392:assumed-role/AWSReservedSSO_idp-ai-team_1e8502d7dba56763/<user-account>"
}
```

### Step 2: Setup your EKS credentials
We will be using the AWS CLI to interact with our EKS cluster. First, we need to get the kubeconfig file for our EKS cluster.
Run the following command to download the kubeconfig file
```
$ aws eks update-kubeconfig --name eks-001 --region eu-north-1
```
This will add the EKS cluster's credentials to your local kubeconfig file. You can verify this by running the following command
```
$ kubectl config get-contexts
CURRENT   NAME                                                  CLUSTER                                               AUTHINFO                                              NAMESPACE
*         arn:aws:eks:eu-north-1:970547334392:cluster/eks-001   arn:aws:eks:eu-north-1:970547334392:cluster/eks-001   arn:aws:eks:eu-north-1:970547334392:cluster/eks-001
```
You should see the EKS cluster's context listed as the current context.

*Bonus-info: If you want to switch between different contexts, you can use the following command or use the recommended tool kubectx*
```
$ kubectl config use-context <context-name>
```
Beware that the access you have in this cluster is limited to certain api groups and namespaces. The level of restrictions are subject to change based on a need-to basis.

### Step 3: Deploy your application
We are using ArgoCD for GitOPS functionality, so you will be deploying your applications using an ArgoCD Application resource.
The following repository has been set up for your team and everything put in this repository will be deployed to the EKS cluster. The repository is located at `https://github.com/jppol-idp/argocd-eks-001-ai`

Here is an example of a deployment. I will be deploying a Helm chart for [open-webui](https://openwebui.com/) with a bundled Ollama on a spot GPU instance in the kubernetes namespace **ai**. We will get a FQDN with a LetsEncrypt TLS certificate:
1. Clone the repository
2. Create a new branch for your application
3. Create a new YAML file. Lets name it `open-webui.yaml` with the following contents
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: open-webui
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    name: ""
    namespace: ai
    server: https://kubernetes.default.svc
  sources:
    - repoURL: https://helm.openwebui.com
      path: ""
      targetRevision: 3.4.3
      chart: open-webui
      helm:
        valueFiles:
          - $values/01-open-webui-helm-values.yaml
    - repoURL: https://github.com/jppol-idp/argocd-eks-001-ai.git
      targetRevision: main
      ref: values
  project: ai-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
4. We will also need the Helm values file specified in the `valueFiles` section of the YAML file. Lets name it `01-open-webui-helm-values.yaml` with the following contents:
```
ollama:
  enabled: true
  fullnameOverride: "open-webui-ollama"
  ollama:
    gpu:
      enabled: true
      type: "nvidia"
      nvidiaResource: "nvidia.com/gpu"
    models:
      - llama3.2:3b

replicaCount: 1
image:
  repository: ghcr.io/open-webui/open-webui

ingress:
  enabled: true
  class: "nginx-public"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  host: "ai-openweb-demo.jppol.click"
  tls: true
  existingSecret: "ai-openweb-demo"
persistence:
  enabled: true
  size: "5Gi"
```

5. Now create a pull request to merge the changes into the main branch of your repository. Once the pull request is approved and merged, ArgoCD will automatically sync the changes to your Kubernetes cluster.

#### Descriptions of some of the helm chart values
`ingress.class: "nginx-public"` - This specifies the ingress class that should be used for the ingress resource. An ingress class defines a set of parameters that can be used to configure an ingress controller.In this case, we are using the "nginx-public" ingress class, which is provided by an NGINX ingress controller deployed in the cluster.

`ingress.annotations: cert-manager.io/cluster-issuer: letsencrypt` - This specifies annotations for the ingress resource. Annotations can be used to add additional metadata to a Kubernetes resource, and they can also be used to configure certain behaviors of the resource. In this case, we are using an annotation provided by the cert-manager project to specify that the ingress controller should use the "letsencrypt" cluster issuer to obtain TLS certificates for the ingress resource.

`ingress.host: "ai-openweb-demo.jppol.click"` - This specifies the hostname that should be used for the ingress resource. The hostname is used to identify the application and to route incoming requests to the correct service or pod. In this case, we are using the hostname "ai-openweb-demo.jppol.click". This will also create the DNS name in route53 to route traffic to our ingress controller.

`ingress.tls: true` - This specifies whether or not TLS encryption should be enabled for the ingress resource. If set to `true`, then the ingress controller will require clients to present a valid TLS certificate in order to access the application.

`ingress.existingSecret` - This is the name of the kubernetes secret that the ingress controller will look for the TLS certificate. In this case since we are using cert-manager, it specifies the secret that cert-manager will create and manage for us.

`persistence.enabled: true` - This enables persistent storage for the application. Persistent storage allows the application to store data on a disk or other storage device, even if the pod is restarted or deleted. In this case, we are enabling persistent storage for the application, which means that any data stored by the application will be preserved across pod restarts

### Step 4: Check application deployment status
#### ArgoCD Gui
Please go to ArgoCD gui at https://argocd.jppol.click and login using GitHub authentification.
You should see the application **open-webui** and if you click it you can check the current status of the deployment.
Be aware that since this test deployment requests a new GPU instance, creates DNS and Certificates, it might take a few minutes for everything to be ready

#### Kubectl
You can also use kubectl to check the status of the application. Run the following command
```
$ kubectl get pods -n ai
```

### Step 5: Access the application
Once the application is deployed and running, you should be able to access it by navigating to the URL specified in the ingress resource. In this case, the URL will be `https://ai-openweb-demo.jppol.click`.

### Step 6. Logging and metrics
#### Logs
All stdout and stderr of the pods are sent to a centralized logging system, which in our case is Grafana Loki You can access these logs by going to https://grafana.jppol.click and log in using your GitHub authentification. Once logged in, you should be able to see all the logs for the application by going to **Explore** and selecting the appropriate log stream.

You also have the option to use kubectl for logs.
```
$ kubectl get pods -n ai
$ kubectl logs -n ai <pod-name>
```

#### Metrics
All metrics are sent to a centralized monitoring system, which in our case is Prometheus You can access these metrics the same way you access logs by going to https://grafana.jppol.click and log in using your GitHub authentification. Once logged in, you should be able to see all the metrics for the application by going to **Explore** and choose **Prometheus** as datasource and then select the metric you want.
