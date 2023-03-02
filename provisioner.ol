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
    protocol: "sodep"
    interfaces: ProvisionerAPI
  }


  outputPort Jocker {
    Location: "socket://localhost:8008"
    Protocol: "sodep"
    Interfaces: InterfaceAPI
  }

  main {
    at( request )( response ) {
      containers@Jocker({
        all = true
      })(test)
      foreach(container : test.container) {
        println@Console("name: " + container.Names[0])()
      }
      response.node = "test"
    }
  }
}

