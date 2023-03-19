interface ChecksumInterface {
  RequestResponse:
    println( string )( string )
}

service Checksum {
  inputPort Input {
    location: "local"
    interfaces: ChecksumInterface
  } foreign java {
    class: "jfn.Checksum"
  }
}
