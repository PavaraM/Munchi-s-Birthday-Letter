variable "tenancy_ocid" {
  description = "Tenancy OCID from the OCI console"
  type        = string
}

variable "user_ocid" {
  description = "User OCID of the API key principal (only if not using OCI CLI config)"
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "API key fingerprint (only if not using OCI CLI config)"
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "Path to the API signing key PEM (only if not using OCI CLI config)"
  type        = string
  default     = ""
}

variable "region" {
  description = "OCI region. Always Free A1 instances are only available in your HOME REGION."
  type        = string
}

variable "compartment_name" {
  description = "Name of the compartment to create (when compartment_ocid is empty)"
  type        = string
  default     = "munchi-birthday"
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ssh_public_key" {
  description = "Your public SSH key (contents) for the opc user"
  type        = string
}

variable "availability_domain_index" {
  description = "Index into the list of availability domains to try (retry 0..N if capacity is unavailable)"
  type        = number
  default     = 0
}

variable "instance_ocpus" {
  description = "A1 OCPUs (Always Free max = 4)"
  type        = number
  default     = 4
}

variable "instance_memory_gbs" {
  description = "A1 memory in GB (Always Free max = 24)"
  type        = number
  default     = 24
}
