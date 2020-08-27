target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Shairport Sync"
    BUILD_DESCRIPTION = "A dubo image for Shairport Sync"
  }
  tags = [
    "dubodubonduponey/shairport-sync",
  ]
}
