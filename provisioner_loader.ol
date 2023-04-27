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
    getenv@Runtime( "ADVERTISE_LOCATION" )( params.advertiseLocation )
    getenv@Runtime( "JOCKER_LOCATION" )( params.jockerLocation )
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( params.functionCatalogLocation )

    getenv@Runtime( "DOCKER_NETWORK" )( params.dockerNetwork )
    getenv@Runtime( "CALLS_PER_RUNNER" )( params.callsPerRunner )
    params.callsPerRunner = int(params.callsPerRunner)
    getenv@Runtime( "CALLS_FOR_PROMOTION" )( params.callsForPromotion )
    params.callsForPromotion = int(params.callsForPromotion)
    getenv@Runtime( "MIN_RUNNERS" )( params.minRunners )
    params.minRunners = int(params.minRunners)

    if(params.minRunners <= 0) {
      println@Console("At least one runner is required. MIN_RUNNERS has been defaulted to 1")()
      params.minRunners = 1
    }
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
