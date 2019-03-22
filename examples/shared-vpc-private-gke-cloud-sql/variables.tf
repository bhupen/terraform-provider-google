variable "region" {
  default = "us-central1"
}

variable "region_zone" {
  default = "us-central1-f"
}

variable "org_id" {
  description = "The ID of the Google Cloud Organization."
  default = ""
}

variable "billing_account_id" {
  description = "The ID of the associated billing account (optional)."
  default = ""
}

variable "credentials_file_path" {
  description = "Location of the credentials to use."
  default     = "~/.gcloud/Terraform.json"
}

variable "folder_id" {
  default = ""
}

variable "peering_address_range_name" {
  default ="google-managed-services-range"
}

variable "peering_cidr_range" {
  default = "192.168.0.0"
}

variable "peering_cidr_prefix" {
  default = "17"
}
