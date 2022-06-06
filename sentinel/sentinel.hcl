module "tfplan-functions" {
    source = "./common-functions/tfplan-functions/tfplan-functions.sentinel"
}

module "tfstate-functions" {
    source = "./common-functions/tfstate-functions/tfstate-functions.sentinel"
}

module "tfconfig-functions" {
    source = "./common-functions/tfconfig-functions/tfconfig-functions.sentinel"
}

module "tfrun-functions" {
    source = "./common-functions/tfrun-functions/tfrun-functions.sentinel"
}

policy "allowed-providers" {
    source = "./allowed-providers.sentinel"
    enforcement_level = "advisory"
}

policy "terraform-versions" {
    source = "./terraform-versions.sentinel"
    enforcement_level = "advisory"
}

policy "restrict-gke-clusters" {
    source = "./restrict-gke-clusters.sentinel"
    enforcement_level = "advisory"
}

# policy "bridgecrew" {
#         source            = "./bridgecrew.sentinel"
#         enforcement_level = "hard-mandatory"
# }
