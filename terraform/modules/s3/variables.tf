variable "vite_build_folder" {
  type        = string
  description = "Path to the Vite build output folder"
  default     = "./dist"
}


variable "vite_api_url" {
    type        = string
    description = "API URL to be used in the Vite build"
    validation {
        condition     = can(regex("https?://", var.vite_api_url))
        error_message = "Vite API URL must start with http:// or https://"
    }
}
  