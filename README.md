# Secure Azure Linux VM with Terraform

This project creates an Azure resource group and deploys an Ubuntu 22.04 LTS VM
and its network resources into it. Authentication is passwordless:

- Local operators use their short-lived Azure CLI session.
- Terraform state is stored in Azure Blob Storage using Entra ID authorization.
- The VM accepts SSH keys only, with port 22 limited to one configured CIDR.

The VNet and subnet use `10.73.42.0/29`, the smallest Azure IPv4 subnet size.
It contains eight addresses; Azure reserves five, leaving three usable addresses
for the VM NIC and limited future platform use.

The subscription policy allows deployments in Italy North, Poland Central,
Spain Central, Sweden Central, and Switzerland North. The configuration uses
`swedencentral` with a `Standard_D2als_v6` learning VM (two vCPUs and 4 GiB
RAM). The subscription-specific Compute SKU API reports this SKU as
unrestricted, and its Dalsv6 family has a 10-vCPU quota. All smaller legacy B
sizes are unavailable for this subscription in the approved regions, despite
the nominal BS-family quota. The VM uses Canonical's x64 Ubuntu 22.04 Gen2
image because Dalsv6 supports Hyper-V Generation 2 only.
The existing resource group's metadata location remains `uksouth`; Azure permits
resources inside a resource group to use a different region.

## Security model

Never put an Azure client secret, password, access key, or private SSH key in
this repository or in `terraform.tfvars`. The Azure subscription ID, tenant ID,
client ID, resource-group name, and SSH **public** key are identifiers rather
than secrets and can be stored as GitHub environment variables.

The deployment resource group is bootstrapped outside Terraform so the
deployment identity can use resource-group-scoped permissions. Grant the
deployment identity only:

- `Contributor` on the pre-created `rg-terraform-vm` resource group
- `Storage Blob Data Contributor` on the Terraform state container

Do not grant `Owner`; role-assignment creation is not required by this project.

## Local deployment

Sign in interactively and select the subscription. Terraform automatically uses
the Azure CLI session; no credentials are written into Terraform files.

```bash
az login
az account set --subscription "<subscription-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"

cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit both files. Set allowed_ssh_cidr to your public IP with /32.

terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

State and plan files are ignored by Git. The remote state container must have
soft delete and versioning enabled and should be protected from public access.

If resources already exist in local state, migrate them once after creating the
backend and before running GitHub Actions:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Confirm the migration with `terraform state list`. Do not run the deployment
workflow against an empty remote state while the Azure resources already exist.

## GitHub Actions deployment

The workflow passes GitHub's OIDC identity directly to Terraform and the Azure
Storage backend. Azure workload identity federation exchanges that short-lived
identity for Azure access, so neither an Azure CLI session nor a client secret
is needed in CI. Create an Entra application or user-assigned managed identity
with a federated credential using:

```text
Issuer:   https://token.actions.githubusercontent.com
Audience: api://AzureADTokenExchange
Subject:  repo:<owner>/<repository>:environment:azure-production
```

Create a protected GitHub environment named `azure-production` and configure
required reviewers. The non-secret Azure identifiers, deployment location,
allowed SSH CIDR, SSH public key, and state-backend names are set directly in
the workflow. If your public IP or SSH key changes, update the corresponding
workflow environment value before deploying.

The identity needs deployment permissions plus `Storage Blob Data Contributor`
on the state container. Terraform receives `ARM_USE_OIDC=true` and uses the
GitHub-provided token endpoint to request a short-lived token for this identity.
Run the workflow manually with `plan`, review it, then run it again with
`apply`. To remove Terraform-managed VM and network resources, run it with
`destroy`; the workflow creates and applies a saved destroy plan. The
`azure-production` environment approval protects all operations, and
Terraform's state lock prevents concurrent deployments.

## Remove the VM resources

```bash
terraform destroy
```

Terraform removes the VM and network resources it created. The bootstrapped VM
resource group and the separate state resource group remain in Azure.

## Nginx container deployment

The `Deploy Nginx container` GitHub Actions workflow packages the files under
`nginx/` and deploys them to `/opt/aiinc/nginx` on the VM. It authenticates to
Azure with the repository's existing OIDC identity and uses Azure VM Run
Command, so no private SSH key is stored in GitHub.

Terraform owns the port 80 NSG rule. The deployment workflow runs when its
files change on `main`, or it can be started manually from the Actions tab.

The workflow expects the protected `azure-production` GitHub environment and
its federated credential to already exist. The deployment identity must have a
role containing `Microsoft.Compute/virtualMachines/runCommands/write`, such as
Virtual Machine Contributor, on the VM resource group.

## License

No license has been selected yet.
# terraform
