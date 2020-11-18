package bake

command: {
  image: #Dubo & {
    args: {
      BUILD_TITLE: "Shairport Sync"
      BUILD_DESCRIPTION: "A dubo image for Shairport Sync based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }
  }
}
