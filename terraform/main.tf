terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
locals {
  system_message = templatefile("./system-prompt.tpl", {})

  # Supported App Service regions with mappings to OpenAI regions
  asp_supported_regions = {
    "eastus2" = {
      location      = "East US 2"
      instances     = 1
      openai_region = "eastus2" # Direct mapping - OpenAI exists here and only supported on built in vectorization for search
    },
    "westus" = {
      location      = "West US"
      instances     = 1
      openai_region = "eastus2" # Map to westus3 for OpenAI
    },
    "westcentralus" = {
      location      = "West Central US"
      instances     = 1
      openai_region = "eastus2" # Map to northcentralus for OpenAI
    }
  }


  # Generate all ASP configurations
  all_asps = flatten([
    for region, config in local.asp_supported_regions : [
      for i in range(1, config.instances + 1) : {
        name          = "${region}-${i}"
        region        = region
        location      = config.location
        openai_region = config.openai_region
      }
    ]
  ])
  primary_region = [for k, v in var.regions : v if v.primary][0]
  embedding_regions = {
    for k, v in var.regions : k => v if v.supports_embedding
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource group reference
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# App Service Plans - one per region
resource "azurerm_service_plan" "asp" {
  for_each = { for asp in local.all_asps : asp.name => asp }

  name                = "air-hr-${each.key}"
  location            = each.value.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "P1v3" # Adjusted as needed
}

# Create the Azure OpenAI services across regions
resource "azurerm_cognitive_account" "openai" {
  for_each = var.regions

  name                = "air-hr-${each.key}"
  location            = each.value.name
  resource_group_name = data.azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
  tags = {
    environment = "production"
    region      = each.value.location
    primary     = each.value.primary
  }
}

# Deploy the text-embedding-large model in each region
resource "azurerm_cognitive_deployment" "embedding" {
  for_each = local.embedding_regions

  name                 = "text-embedding-3-large"
  cognitive_account_id = azurerm_cognitive_account.openai[each.key].id


  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  sku {
    name     = "Standard"
    capacity = 350
  }

}

# Deploy the GPT-4o model in each region
resource "azurerm_cognitive_deployment" "gpt4o" {
  for_each = azurerm_cognitive_account.openai

  name                 = "gpt-4o"
  cognitive_account_id = each.value.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 900
  }
}

# App Services - one per region
resource "azurerm_linux_web_app" "app" {

  for_each = { for asp in local.all_asps : asp.name => asp }

  name                    = "air-hr-${each.key}"
  location                = each.value.location
  resource_group_name     = data.azurerm_resource_group.rg.name
  service_plan_id         = azurerm_service_plan.asp[each.key].id
  client_affinity_enabled = true

  app_settings = {
    "DEBUG"                                 = true
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.central.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.central.connection_string
    "APPINSIGHTS_PROFILERFEATURE_VERSION"   = "disabled"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"   = "disabled"
    "AUTH_CLIENT_SECRET"                    = ""
    "AUTH_ENABLED"                          = "False"
    #"AZURE_COSMOSDB_ACCOUNT"                          = "db-yrci-large"
    #"AZURE_COSMOSDB_CONVERSATIONS_CONTAINER"          = "conversations"
    #"AZURE_COSMOSDB_DATABASE"                         = "db_conversation_history"
    "AZURE_COSMOSDB_MONGO_VCORE_CONNECTION_STRING" = ""
    "AZURE_COSMOSDB_MONGO_VCORE_CONTAINER"         = ""
    "AZURE_COSMOSDB_MONGO_VCORE_CONTENT_COLUMNS"   = ""
    "AZURE_COSMOSDB_MONGO_VCORE_DATABASE"          = ""
    "AZURE_COSMOSDB_MONGO_VCORE_FILENAME_COLUMN"   = ""
    "AZURE_COSMOSDB_MONGO_VCORE_INDEX"             = ""
    "AZURE_COSMOSDB_MONGO_VCORE_TITLE_COLUMN"      = ""
    "AZURE_COSMOSDB_MONGO_VCORE_URL_COLUMN"        = ""
    "AZURE_COSMOSDB_MONGO_VCORE_VECTOR_COLUMNS"    = ""
    "AZURE_OPENAI_EMBEDDING_ENDPOINT"              = azurerm_cognitive_account.openai[var.regions[each.value.openai_region].nearest_embedding_region].endpoint
    "AZURE_OPENAI_EMBEDDING_KEY"                   = azurerm_cognitive_account.openai[var.regions[each.value.openai_region].nearest_embedding_region].primary_access_key
    # "AZURE_OPENAI_EMBEDDING_DEPLOYMENT"               = var.regions[each.value.openai_region].supports_embedding ? azurerm_cognitive_deployment.embedding[each.value.openai_region].name : azurerm_cognitive_deployment.embedding[var.regions[each.value.openai_region].nearest_embedding_region].name
    "AZURE_OPENAI_EMBEDDING_NAME"                     = "text-embedding-3-large"
    "AZURE_OPENAI_ENDPOINT"                           = azurerm_cognitive_account.openai[each.value.openai_region].endpoint
    "AZURE_OPENAI_KEY"                                = azurerm_cognitive_account.openai[each.value.openai_region].primary_access_key
    "AZURE_OPENAI_MAX_TOKENS"                         = "8096"
    "AZURE_OPENAI_MODEL"                              = "gpt-4o"
    "AZURE_OPENAI_MODEL_NAME"                         = "gpt-4o"
    "AZURE_OPENAI_RESOURCE"                           = azurerm_cognitive_account.openai[each.value.openai_region].name
    "AZURE_OPENAI_STOP_SEQUENCE"                      = ""
    "AZURE_OPENAI_SYSTEM_MESSAGE"                     = local.system_message
    "AZURE_OPENAI_TEMPERATURE"                        = "0.7"
    "AZURE_OPENAI_TOP_P"                              = "0.95"
    "AZURE_SEARCH_CONTENT_COLUMNS"                    = "content"
    "AZURE_SEARCH_ENABLE_IN_DOMAIN"                   = "false"
    "AZURE_SEARCH_FILENAME_COLUMN"                    = "hierarchyPath"
    "AZURE_SEARCH_INDEX"                              = "cfr-regulations"
    "AZURE_SEARCH_KEY"                                = azurerm_search_service.search.primary_key
    "AZURE_SEARCH_PERMITTED_GROUPS_COLUMN"            = ""
    "AZURE_SEARCH_QUERY_TYPE"                         = "vector_semantic_hybrid"
    "AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG"             = "cfr-semantic-config"
    "AZURE_SEARCH_SERVICE"                            = azurerm_search_service.search.name
    "AZURE_SEARCH_STRICTNESS"                         = "3"
    "AZURE_SEARCH_TITLE_COLUMN"                       = "partHeading"
    "AZURE_SEARCH_TOP_K"                              = "50"
    "AZURE_SEARCH_URL_COLUMN"                         = "partHeading"
    "AZURE_SEARCH_USE_SEMANTIC_SEARCH"                = "true"
    "AZURE_SEARCH_VECTOR_COLUMNS"                     = "vector"
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~3"
    "DATASOURCE_TYPE"                                 = "AzureCognitiveSearch"
    "DEBUG"                                           = "True"
    "DiagnosticServices_EXTENSION_VERSION"            = "disabled"
    "ELASTICSEARCH_CONTENT_COLUMNS"                   = ""
    "ELASTICSEARCH_EMBEDDING_MODEL_ID"                = ""
    "ELASTICSEARCH_ENABLE_IN_DOMAIN"                  = "false"
    "ELASTICSEARCH_ENCODED_API_KEY"                   = ""
    "ELASTICSEARCH_ENDPOINT"                          = ""
    "ELASTICSEARCH_FILENAME_COLUMN"                   = ""
    "ELASTICSEARCH_INDEX"                             = ""
    "ELASTICSEARCH_QUERY_TYPE"                        = ""
    "ELASTICSEARCH_STRICTNESS"                        = "3"
    "ELASTICSEARCH_TITLE_COLUMN"                      = ""
    "ELASTICSEARCH_TOP_K"                             = "5"
    "ELASTICSEARCH_URL_COLUMN"                        = ""
    "ELASTICSEARCH_VECTOR_COLUMNS"                    = ""
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "MONGODB_APP_NAME"                                = ""
    "MONGODB_COLLECTION_NAME"                         = ""
    "MONGODB_CONTENT_COLUMNS"                         = ""
    "MONGODB_DATABASE_NAME"                           = ""
    "MONGODB_ENABLE_IN_DOMAIN"                        = "false"
    "MONGODB_ENDPOINT"                                = ""
    "MONGODB_FILENAME_COLUMN"                         = ""
    "MONGODB_INDEX_NAME"                              = ""
    "MONGODB_PASSWORD"                                = ""
    "MONGODB_STRICTNESS"                              = "3"
    "MONGODB_TITLE_COLUMN"                            = ""
    "MONGODB_TOP_K"                                   = "5"
    "MONGODB_URL_COLUMN"                              = ""
    "MONGODB_USERNAME"                                = ""
    "MONGODB_VECTOR_COLUMNS"                          = ""
    "SCM_DO_BUILD_DURING_DEPLOYMENT"                  = "true"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"

  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    ip_restriction {
      service_tag = "AzureFrontDoor.Backend"
      name        = "Allow Front Door Only"
      priority    = 100
      action      = "Allow"
      headers {
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.frontdoor.resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }
    }

    # Block everything else
    ip_restriction {
      ip_address = "0.0.0.0/0"
      name       = "Deny All"
      priority   = 2147483647 # Lowest priority (last rule)
      action     = "Deny"
    }
    always_on           = true
    minimum_tls_version = "1.2"
    ftps_state          = "FtpsOnly"
    app_command_line    = "python3 -m gunicorn app:app"
    http2_enabled       = false
  }

  auth_settings_v2 {
    auth_enabled             = false
    default_provider         = "azureactivedirectory"
    excluded_paths           = []
    forward_proxy_convention = "NoProxy"
    http_route_api_prefix    = "/.auth"
    require_authentication   = true
    require_https            = true
    runtime_version          = "~1"
    unauthenticated_action   = "RedirectToLoginPage"

    active_directory_v2 {
      allowed_applications            = []
      allowed_audiences               = []
      allowed_groups                  = []
      allowed_identities              = []
      client_id                       = "7f5c56b7-a251-4dc7-95ff-9bdc89d4afb7"
      client_secret_setting_name      = "AUTH_CLIENT_SECRET"
      jwt_allowed_client_applications = []
      jwt_allowed_groups              = []
      login_parameters = {
        "response_type" = "code id_token"
        "scope"         = "openid offline_access profile https://graph.microsoft.com/User.Read"
      }
      tenant_auth_endpoint        = "https://login.microsoftonline.com/bffe4a04-f583-41be-9a3e-0fa4b1c82af3/v2.0"
      www_authentication_disabled = false
    }


    login {
      allowed_external_redirect_urls    = []
      cookie_expiration_convention      = "FixedTime"
      cookie_expiration_time            = "08:00:00"
      nonce_expiration_time             = "00:05:00"
      preserve_url_fragments_for_logins = false
      token_refresh_extension_time      = 72
      token_store_enabled               = true
      validate_nonce                    = true
    }

  }

  logs {
    detailed_error_messages = false
    failed_request_tracing  = false

    http_logs {
      file_system {
        retention_in_days = 5
        retention_in_mb   = 35
      }
    }
  }

  sticky_settings {
    app_setting_names = [
      "APPINSIGHTS_INSTRUMENTATIONKEY",
      "APPINSIGHTS_PROFILERFEATURE_VERSION",
      "APPINSIGHTS_SNAPSHOTFEATURE_VERSION",
      "ApplicationInsightsAgent_EXTENSION_VERSION",
      "DiagnosticServices_EXTENSION_VERSION",
      "InstrumentationEngine_EXTENSION_VERSION",
      "SnapshotDebugger_EXTENSION_VERSION",
      "XDT_MicrosoftApplicationInsights_BaseExtensions",
      "XDT_MicrosoftApplicationInsights_Mode",
      "XDT_MicrosoftApplicationInsights_PreemptSdk",
      "APPLICATIONINSIGHTS_CONNECTION_STRING ",
      "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
      "XDT_MicrosoftApplicationInsightsJava",
      "XDT_MicrosoftApplicationInsights_NodeJS",
    ]
  }

  identity {
    type = "SystemAssigned"
  }

  https_only = true

  tags = {
    ProjectType = "aoai-your-data-service"
  }
}


resource "azurerm_app_service_source_control" "github" {
  for_each               = azurerm_linux_web_app.app
  app_id                 = each.value.id
  repo_url               = "https://github.com/leolorenzoluis/yrci-psi.git"
  branch                 = "main"
  use_manual_integration = true

}

# Use local-exec provisioner to force sync after apply
resource "null_resource" "sync_git_repo" {
  for_each = azurerm_linux_web_app.app

  triggers = {

    # The timestamp will be different on every run, forcing this resource to be recreated each time
    always_run = timestamp()
    app_id     = each.value.id
  }

  provisioner "local-exec" {
    command = "az webapp deployment source sync --name ${each.value.name} --resource-group ${data.azurerm_resource_group.rg.name}"
  }

  depends_on = [azurerm_app_service_source_control.github]
}

# Global Front Door Profile
resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  name                     = "frontdoor"
  resource_group_name      = data.azurerm_resource_group.rg.name
  sku_name                 = "Standard_AzureFrontDoor"
  response_timeout_seconds = 60
}

# Front Door Endpoints
resource "azurerm_cdn_frontdoor_endpoint" "yrci" {
  name                     = "yrci"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
}

resource "azurerm_cdn_frontdoor_endpoint" "yrci_public" {
  name                     = "yrci-public"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
}

# Origin Groups for different workloads
resource "azurerm_cdn_frontdoor_origin_group" "default_origin_group" {
  name                                                      = "default-origin-group"
  cdn_frontdoor_profile_id                                  = azurerm_cdn_frontdoor_profile.frontdoor.id
  session_affinity_enabled                                  = false
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 0

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/health"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 15
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "public_assets" {
  name                                                      = "public-assets"
  cdn_frontdoor_profile_id                                  = azurerm_cdn_frontdoor_profile.frontdoor.id
  session_affinity_enabled                                  = false
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 0

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Http"
    interval_in_seconds = 15
  }
}



resource "azurerm_cdn_frontdoor_origin" "public_storage" {
  name                          = "public-storage"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.public_assets.id

  host_name                      = "yrciblob.blob.core.windows.net"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "yrciblob.blob.core.windows.net"
  priority                       = 1
  weight                         = 1000
  enabled                        = true
  certificate_name_check_enabled = true
}

# Front Door Custom Domain
resource "azurerm_cdn_frontdoor_custom_domain" "air_hr_ai" {
  name                     = "air-hr-ai-faeb"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
  host_name                = "air-hr.ai"

  tls {
    certificate_type        = "ManagedCertificate"
    cdn_frontdoor_secret_id = "/subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/secrets/0--2c0cddfc-fbc5-472f-8a4c-827b88f1c8f4-air-hr-ai"
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "ratelimit" {
  name                              = "ratelimit"
  resource_group_name               = "yrci-v1"
  sku_name                          = "Standard_AzureFrontDoor"
  enabled                           = true
  mode                              = "Detection"
  custom_block_response_status_code = 429

  # Custom rule for US only access
  custom_rule {
    name                           = "usonly"
    enabled                        = true
    priority                       = 1
    type                           = "MatchRule"
    action                         = "Block"
    rate_limit_duration_in_minutes = 0
    rate_limit_threshold           = 0

    match_condition {
      match_variable     = "SocketAddr"
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = ["US"]
      transforms         = []
    }
  }

  # Rate limit rule
  custom_rule {
    name                           = "ratelimit"
    enabled                        = true
    priority                       = 2
    type                           = "RateLimitRule"
    action                         = "Block"
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 500

    match_condition {
      match_variable     = "RequestHeader"
      selector           = "Host"
      operator           = "GreaterThanOrEqual"
      negation_condition = false
      match_values       = ["0"]
      transforms         = []
    }
  }
}

# Front Door Security Policy
resource "azurerm_cdn_frontdoor_security_policy" "ratelimit" {
  name                     = "ratelimit-b7043f4b"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = "/subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Network/frontDoorWebApplicationFirewallPolicies/ratelimit"

      association {
        patterns_to_match = ["/*"]
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.yrci.id
        }
      }
    }
  }
}

# Front Door Routes
resource "azurerm_cdn_frontdoor_route" "default_route" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.yrci.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.default_origin_group.id
  cdn_frontdoor_origin_ids      = []

  patterns_to_match = ["/*"]

  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = true
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = true

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.air_hr_ai.id]
}

resource "azurerm_cdn_frontdoor_origin" "air-hr-origin" {
  for_each                      = azurerm_linux_web_app.app
  name                          = each.key
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.default_origin_group.id

  host_name                      = each.value.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = each.value.default_hostname
  priority                       = 1
  weight                         = 1000
  enabled                        = true
  certificate_name_check_enabled = true
}

# Public assets route
resource "azurerm_cdn_frontdoor_route" "yrci_public" {
  name                          = "yrci-public"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.yrci_public.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.public_assets.id
  cdn_frontdoor_origin_ids      = []

  patterns_to_match = ["/*"]

  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = true
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = true

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress = [
      "application/eot", "application/font", "application/font-sfnt", "application/javascript",
      "application/json", "application/opentype", "application/otf", "application/pkcs7-mime",
      "application/truetype", "application/ttf", "application/vnd.ms-fontobject", "application/xhtml+xml",
      "application/xml", "application/xml+rss", "application/x-font-opentype", "application/x-font-truetype",
      "application/x-font-ttf", "application/x-httpd-cgi", "application/x-javascript", "application/x-mpegurl",
      "application/x-opentype", "application/x-otf", "application/x-perl", "application/x-ttf",
      "font/eot", "font/ttf", "font/otf", "font/opentype", "image/svg+xml", "text/css",
      "text/csv", "text/html", "text/javascript", "text/js", "text/plain", "text/richtext",
      "text/tab-separated-values", "text/xml", "text/x-script", "text/x-component", "text/x-java-source"
    ]
  }
}


# Auto Scaling rules for each regional App Service
# Auto Scaling rules for each regional App Service
resource "azurerm_monitor_autoscale_setting" "app_service_autoscale" {
  for_each = azurerm_service_plan.asp

  name                = "app-autoscale-${each.key}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = each.value.location
  target_resource_id  = each.value.id

  profile {
    name = "DefaultProfile"

    capacity {
      default = 2  # Start with 2 instances
      minimum = 1  # Minimum 1 instance
      maximum = 10 # Maximum 10 instances
    }

    # Scale out rule based on CPU
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M" # 1 minute
        statistic          = "Average"
        time_window        = "PT5M" # Look back 5 minutes
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70 # Scale out when CPU > 70%
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"    # Add 1 instance
        cooldown  = "PT5M" # Wait 5 minutes before next scale-out action
      }
    }

    # Scale in rule based on CPU
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M" # Look back 10 minutes (longer to avoid premature scale-in)
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30 # Scale in when CPU < 30%
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"     # Remove 1 instance
        cooldown  = "PT10M" # Wait 10 minutes before next scale-in action (longer for stability)
      }
    }

    # Scale out based on HTTP queue length - good for chat app that may have bursts
    rule {
      metric_trigger {
        metric_name        = "HttpQueueLength"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT3M" # React quickly to queued requests
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 30 # If more than 30 requests are queued
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2" # Add 2 instances for queue backlogs (more aggressive)
        cooldown  = "PT3M"
      }
    }

    # Scale out based on memory percentage - important for ChatGPT API calls
    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75 # Memory > 75%
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  # Business hours profile for weekday mornings - Starting the day
  profile {
    name = "BusinessMorningProfile"

    capacity {
      default = 1 # Higher default during business hours
      minimum = 1 # Higher minimum to ensure good performance
      maximum = 30
    }

    # Same CPU scaling rules
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    # Business hours morning - 8 AM
    recurrence {
      timezone = "Eastern Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [8]
      minutes  = [0]
    }
  }

  # Weekend profile
  profile {
    name = "WeekendProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5 # Lower maximum for weekends
    }

    # Same CPU rules but higher threshold to scale out
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80 # Higher threshold (80% vs 70%)
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20 # Scale in more aggressively
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    # Weekend schedule - Saturday at midnight
    recurrence {
      timezone = "Eastern Standard Time"
      days     = ["Saturday", "Sunday"]
      hours    = [0]
      minutes  = [0]
    }
  }

  # Evening/night profile
  profile {
    name = "EveningProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5 # Lower maximum for evenings
    }

    # Same CPU rules as weekend
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80 # Higher threshold (80% vs 70%)
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = each.value.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    # Weekday evenings at 6 PM
    recurrence {
      timezone = "Eastern Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [18]
      minutes  = [0]
    }
  }
}

resource "azurerm_application_insights" "central" {
  name                = "air-hr-central-appinsights"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  application_type    = "web"
  # Optional: workspace_id if using Log Analytics
}

resource "azurerm_search_service" "search" {
  name                = "yrci"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "standard"
  replica_count       = 1
  partition_count     = 1
  hosting_mode        = "default"

  public_network_access_enabled = true
  local_authentication_enabled  = true

  semantic_search_sku = "standard"

  # Note: These fields will be managed by Terraform after import
  lifecycle {
    ignore_changes = [
      tags["ProjectType"]
    ]
  }
}
