variable "REGISTRY" {
  default = "docker.io"
}

target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Shairport Sync"
    BUILD_DESCRIPTION = "A dubo image for Shairport Sync"
  }
  tags = [
    "${REGISTRY}/dubodubonduponey/shairport-sync",
  ]
}
