variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "yrci-v1"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  default     = "797a03a0-9429-4393-8662-327191141b7b"
}

variable "regions" {
  description = "Regions to deploy resources"
  type = map(object({
    name                     = string
    location                 = string
    primary                  = bool
    supports_embedding       = bool
    nearest_embedding_region = string
  }))
  default = {
    eastus2 = {
      name                     = "eastus2"
      location                 = "East US 2"
      primary                  = true
      supports_embedding       = true
      nearest_embedding_region = "eastus2"
    },
    westus2 = {
      name                     = "westus"
      location                 = "West US"
      primary                  = false
      supports_embedding       = false
      nearest_embedding_region = "westus3"
    },
    southcentralus = {
      name                     = "southcentralus"
      location                 = "South Central US"
      primary                  = false
      supports_embedding       = false
      nearest_embedding_region = "eastus2"
    },
    northcentralus = {
      name                     = "northcentralus"
      location                 = "North Central US"
      primary                  = false
      supports_embedding       = false
      nearest_embedding_region = "eastus2"
    },
    westus3 = {
      name                     = "westus3"
      location                 = "West US 3"
      primary                  = false
      supports_embedding       = true
      nearest_embedding_region = "westus3"
    }
  }
}

