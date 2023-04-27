from console import Console
from runtime import Runtime
from string_utils import StringUtils
from .jocker import InterfaceAPI

type SpawnerParams {
  jockerLocation: string
}

type SpawnRequest {
  name: string
  type: string
  image: string

  provisionerLocation: string
  functionCatalogLocation: string
  function?: string
  verbose: bool
  debug: bool
}

type KillRequest {
  id: string
}

interface SpawnerAPI {
  RequestResponse:
    spwn( SpawnRequest )( string )
}

service Spawner( p : SpawnerParams ) {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed StringUtils as StringUtils

  outputPort Jocker {
    Location: p.jockerLocation
    protocol: sodep
    Interfaces: InterfaceAPI
  }

  inputPort SpawnerInput {
    location: "local"
    protocol: sodep
    interfaces: SpawnerAPI
  }

  init {
    enableTimestamp@Console(true)()
    
    // TODO: fix
    p.dockerNetwork = "jfn"
    p.verbose = true
    p.debug = true
  }

  main {
    [spwn( request )( response ) {
      // both environment variables are set to be generic
      env[#env] = "RUNNER_LOCATION=socket://0.0.0.0:8010"
      env[#env] = "SINGLETON_LOCATION=socket://0.0.0.0:8010"
      env[#env] = "ADVERTISE_LOCATION=socket://" + request.name + ":8010"

      env[#env] = "PROVISIONER_LOCATION=" + request.provisionerLocation
      env[#env] = "PROVISIONER_LOCATION=" + request.provisionerLocation
      env[#env] = "FUNCTION_CATALOG_LOCATION=" + request.functionCatalogLocation
      env[#env] = "VERBOSE=" + request.verbose
      env[#env] = "DEBUG=" + request.debug
      if(is_defined(request.function)) {
        env[#env] = "FUNCTION=" + request.function
      }
      createContainer@Jocker({
        name = request.name
        Hostname = request.name
        Domainname = request.name
        Image = request.image
        HostConfig << {
          NetworkMode = p.dockerNetwork
        } 
        Env << env
      })(res)
      if(p.debug) {
        valueToPrettyString@StringUtils( res )( t )
        println@Console( "Create container response: " + t )()
      }
      if(#res.Warnings > 0) {
        for(i = 0, i < #res.Warnings, i++) {
          println@Console("Docker warning: " + res.Warnings[i])()
        }
      }
      if(p.verbose) {
        println@Console("Created container: " + res.Id)()
      }

      startContainer@Jocker({ id = res.Id })(start_log)
      if(p.debug) {
        valueToPrettyString@StringUtils( start_log )( t )
        println@Console( "Start container response: " + t )()
      }
      response = res.Id
    }]
  }
}
