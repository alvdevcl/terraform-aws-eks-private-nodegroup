variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}

variable "enable_cluster_autoscaler" {
  type        = bool
  description = "Whether to enable node group to scale the Auto Scaling Group"
  default     = false
}

variable "vpc_id" {
  description = "VPC Id for the cluster. Found an issue with VPC Dynamic Lookup, so this needs to be passed in."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs to launch resources in"
  type        = list(string)
}

variable "node_group_name" {
  type        = string
  description = "Solution name, e.g. 'app' or 'cluster'"
}

variable "node_role_arn" {
  type        = string
  description = "Arn of the IAM role used by the nodes. Creates `<cluster_name>-<node_group_name>` IAM role if not specified"
  default     = null
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `{ BusinessUnit = \"XYZ\" }`"
}

variable "node_group_ssh_key" {
  type        = string
  description = "SSH key name that should be used to access the worker nodes"
  default     = null
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
}

variable "existing_workers_role_policy_arns" {
  type        = list(string)
  default     = []
  description = "List of existing policy ARNs that will be attached to the workers default role on creation"
}

variable "existing_workers_role_policy_arns_count" {
  type        = number
  default     = 0
  description = "Count of existing policy ARNs that will be attached to the workers default role on creation. Needed to prevent Terraform error `count can't be computed`"
}

variable "ami_type" {
  type        = string
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group. Defaults to `BOTTLEROCKET_x86_64`. Valid values: `AL2_x86_64`, `AL2_x86_64_GPU`, `AL2_ARM_64`, `BOTTLEROCKET_ARM_64`, `BOTTLEROCKET_x86_64`, `BOTTLEROCKET_ARM_64_NVIDIA`, `BOTTLEROCKET_x86_64_NVIDIA`, `CUSTOM`."
  default     = "BOTTLEROCKET_x86_64"
}

variable "disk_size" {
  type        = number
  description = "Disk size in GiB for worker nodes. Defaults to 20. Terraform will only perform drift detection if a configuration value is provided"
  default     = 20
}

#the EKS API only accepts a single value in the set.
variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Set of instance types associated with the EKS Node Group. Note:the EKS API only accepts a single value in the set."
}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels. Only labels that are applied with the EKS API are managed by this argument. Other Kubernetes labels applied to the EKS Node Group will not be managed"
  default     = {}
}

variable "ami_release_version" {
  type        = string
  description = "AMI version of the EKS Node Group. Defaults to latest version for Kubernetes version"
  default     = null
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version. Defaults to EKS Cluster Kubernetes version. Terraform will only perform drift detection if a configuration value is provided"
  default     = null
}

variable "capacity_type" {
  type        = string
  description = "Type of capacity associate with EKS Node Group. Two values 'ON_DEMAND' or 'SPOT'"
  default     = "ON_DEMAND"
}

variable "module_depends_on" {
  type        = any
  default     = null
  description = "Can be any value desired. Module will wait for this value to be computed before creating node group."
}

variable "permissions_boundary" {
  description = "ARN of IAM policy to apply as a permissions boundary on all roles created by this module. If left unset, will default to the AdminPermissionsBoundary in your account."
  type        = string
  default     = null
}

variable "additional_assume_role_policies" {
  description = "string for additional client provided assume role policies for the node role"
  type        = string
  default     = "{}"
}

# vim: ts=2 sw=2 et
