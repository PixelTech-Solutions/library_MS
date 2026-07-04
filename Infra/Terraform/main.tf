resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# --- Azure Container Registry ---
module "acr" {
  source = "./modules/acr"

  project_name        = var.project_name
  environment         = var.environment
  location            = local.rg_location
  resource_group_name = local.rg_name
  sku                 = var.acr_sku
}

# --- Azure Kubernetes Service ---
module "aks" {
  source = "./modules/aks"

  project_name        = var.project_name
  environment         = var.environment
  location            = local.rg_location
  resource_group_name = local.rg_name
  node_count          = var.aks_node_count
  vm_size             = var.aks_vm_size
}

# --- Jenkins VM ---
module "jenkins" {
  source = "./modules/jenkins-vm"

  project_name        = var.project_name
  environment         = var.environment
  location            = local.rg_location
  resource_group_name = local.rg_name
  vm_size             = var.jenkins_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
}

# --- Attach ACR to AKS (allow image pulls) ---
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.kubelet_identity_object_id
  role_definition_name             = "AcrPull"
  scope                            = module.acr.acr_id
  skip_service_principal_aad_check = true
}
