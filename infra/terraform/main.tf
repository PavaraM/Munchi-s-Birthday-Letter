# Munchi's Birthday Letter — Oracle Cloud Infrastructure (Always Free)
#
# Provisions: compartment, VCN, internet gateway, route table, security list,
# public subnet, and an Ampere A1 (ARM) instance. All within the Always Free
# tier (4 OCPU + 24 GB RAM) — must run in your HOME REGION.
#
# Auth: the OCI provider uses your OCI CLI config (~/.oci/config) or
# standard OCI env vars. Configure via terraform.tfvars (see example).

terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region = var.region
}

# ---------------- compartment (optional; reuse root if compartment_ocid set) ----------------
variable "compartment_ocid" {
  description = "Existing compartment to use; leave empty to create a new one"
  default     = ""
}

locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : oci_identity_compartment.main[0].id
}

resource "oci_identity_compartment" "main" {
  count          = var.compartment_ocid != "" ? 0 : 1
  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = "Munchi Birthday Letter infrastructure"
  enable_delete  = true
}

# ---------------- networking ----------------
resource "oci_core_vcn" "main" {
  compartment_id = local.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "munchi-vcn"
  dns_label      = "munchi"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "munchi-igw"
}

resource "oci_core_route_table" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "munchi-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
    description       = "default internet route"
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "munchi-sec-list"

  # ingress: SSH, HTTP, HTTPS only (management port for uptime-kuma stays cloud-blocked)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTP"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTPS"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # egress: allow all
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "allow all egress"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = var.subnet_cidr
  display_name      = "munchi-public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
}

# ---------------- instance ----------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
}

data "oci_core_images" "ol8_aarch64" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "main" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = local.compartment_id
  shape               = "VM.Standard.A1.Flex"
  display_name        = "munchi-birthday"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gbs
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ol8_aarch64.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "munchi-primary-vnic"
  }

  lifecycle {
    # do not destroy the instance on `terraform apply` config drift
    ignore_changes = [shape_config, metadata]
  }
}
