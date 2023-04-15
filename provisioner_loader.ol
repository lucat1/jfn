from console import Console
from runtime import Runtime
from string_utils import StringUtils

interface ProvisionerLoaderAPI {
  RequestResponse:
    noop( void )( void ),
}

service ProvisionerLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local"
    interfaces: ProvisionerLoaderAPI
  }

  init {
    params = {}
    getenv@Runtime( "PROVISIONER_LOCATION" )( params.provisionerLocation )
    getenv@Runtime( "VERBOSE" )( params.verbose )
    params.verbose = bool(params.verbose)
    getenv@Runtime( "DEBUG" )( params.debug )
    params.debug = bool(params.debug)

    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the provisioner with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "provisioner.ol"
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
