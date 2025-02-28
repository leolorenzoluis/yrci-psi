#!/bin/bash
# Initialize Terraform
terraform init


# Import App Service - note the special case for the eastus2 region
terraform import 'azurerm_linux_web_app.app["eastus2"]' /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Web/sites/yrci-large


# Import Front Door Profile
terraform import azurerm_cdn_frontdoor_profile.frontdoor /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor

# Import Front Door Endpoints
terraform import azurerm_cdn_frontdoor_endpoint.yrci /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/afdEndpoints/yrci

terraform import azurerm_cdn_frontdoor_endpoint.yrci_public /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/afdEndpoints/yrci-public

# Import Origin Groups
terraform import azurerm_cdn_frontdoor_origin_group.default_origin_group /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/default-origin-group


terraform import azurerm_cdn_frontdoor_origin_group.public_assets /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/public-assets

terraform import azurerm_cdn_frontdoor_origin_group.multi_region /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/multi-region

# Import Origins
terraform import azurerm_cdn_frontdoor_origin.default_origin /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/default-origin-group/origins/default-origin


terraform import azurerm_cdn_frontdoor_origin.public_storage /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/public-assets/origins/public-storage

terraform import 'azurerm_cdn_frontdoor_origin.app_origins["eastus2"]' /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/originGroups/multi-region/origins/origin-eastus2

# Import Front Door Secret
terraform import azurerm_cdn_frontdoor_secret.air_hr_ai /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/secrets/0--2c0cddfc-fbc5-472f-8a4c-827b88f1c8f4-air-hr-ai

# Import Custom Domain
terraform import azurerm_cdn_frontdoor_custom_domain.air_hr_ai /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/customDomains/air-hr-ai-faeb

# Import Security Policy
terraform import azurerm_cdn_frontdoor_security_policy.ratelimit /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/securityPolicies/ratelimit-b7043f4b

# Import Routes
terraform import azurerm_cdn_frontdoor_route.yrci_public /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/afdEndpoints/yrci-public/routes/yrci-public

terraform import azurerm_cdn_frontdoor_route.default_route /subscriptions/797a03a0-9429-4393-8662-327191141b7b/resourceGroups/yrci-v1/providers/Microsoft.Cdn/profiles/frontdoor/afdEndpoints/yrci/routes/default-route

# Run plan to verify no changes
echo "Running terraform plan to verify no changes..."
terraform plan