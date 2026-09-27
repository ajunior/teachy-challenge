variable "node_image" {
  type        = string
  default     = "kindest/node:v1.36.4"
  description = "kind node image to define the cluster version"
}
