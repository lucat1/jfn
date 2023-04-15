from console import Console
from runtime import Runtime
from string_utils import StringUtils

interface GatewayLoaderAPI {
  RequestResponse:
    noop( void )( void ),
}

service GatewayLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local"
    interfaces: GatewayLoaderAPI
  }

  init {
    params = {}
    getenv@Runtime( "GATEWAY_LOCATION" )( params.gatewayLocation )
    getenv@Runtime( "PROVISIONER_LOCATION" )( params.provisionerLocation )
    getenv@Runtime( "VERBOSE" )( params.verbose )
    params.verbose = bool(params.verbose)

    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the gateway with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "gateway.ol"
      type = "jolie"
      params << params
    })(_)
  }
  main {
    [noop(req)(res) {
      req = res
    }]
  }
}
