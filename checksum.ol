interface ChecksumInterface {
  RequestResponse:
    sha256( string )( string )
}

service Checksum {
  inputPort Input {
    location: "local"
    interfaces: ChecksumInterface
  } foreign java {
    class: "jfn.Checksum"
  }
}
