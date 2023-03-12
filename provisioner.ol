from console import Console
from .jocker import InterfaceAPI

type AtRequest { function: string }
type AtResponse { node: string }

type ProvisionerParams {
  location: string

  verbose: bool
}

interface ProvisionerAPI {
  RequestResponse:
    at( AtRequest )( AtResponse )
}

service Provisioner(p : ProvisionerParams ) {
  execution: concurrent
  embed Console as Console

  inputPort ProvisionerInput {
    location: p.location
    protocol: http { format = "json" }
    interfaces: ProvisionerAPI
  }

  outputPort Jocker {
    Location: "socket://localhost:8008"
    protocol: sodep
    Interfaces: InterfaceAPI
  }

  main {
    at( request )( response ) {
      println@Console("called")()
      containers@Jocker({
        all = true
      })(test)
      for(i = 0, i < #test.container, i++) {
        println@Console("name: " + test.container[i].Names[0])()
      }
      response.node = "test"
    }
  }
}
