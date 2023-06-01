from console import Console
from runtime import Runtime
from string_utils import StringUtils
from .jocker import InterfaceAPI

type SpawnerParams {
  jockerLocation: string
  dockerNetwork: string
  verbose: bool
  debug: bool
}

type SpawnRequest {
  name: string
  image: string

  provisionerLocation: string
  functionCatalogLocation: string
  function?: string
  verbose: bool
  debug: bool
}

type SpwnResponse {
  error: bool
  data?: string
  id?: string
}

type SpwnResponse {
  error: bool
  data?: string
  id?: string
}

type KillResponse {
  error: bool
  data?: string
}

interface SpawnerAPI {
  RequestResponse:
    spwn( SpawnRequest )( SpwnResponse ),
    kill( string )( KillResponse )
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

  define handle_error {
    response.error = true
    valueToPrettyString@StringUtils( err )( err_str )
    response.data = err_str
  }

  init {
    enableTimestamp@Console(true)()
  }

  main {
    [spwn( request )( response ) {
      scope(err) {
        install(
          TypeMismatch => {
            handle_error 
          },
          InvocationFault => {
            handle_error 
          },
          IOException => {
            handle_error 
          },
          Timeout => {
            handle_error 
          }
        )
        // both environment variables are set to be generic
        env[#env] = "RUNNER_NAME=" + request.name
        env[#env] = "SINGLETON_NAME=" + request.name
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
        if(#res.Warnings > 0) {
          for(i = 0, i < #res.Warnings, i++) {
            println@Console("Docker warning: " + res.Warnings[i])()
          }
          response.error = true
          response.data = "got some warnings, please see above"
        } else {
          startContainer@Jocker({ id = res.Id })(start_log)
          if(p.debug) {
            valueToPrettyString@StringUtils( start_log )( t )
            println@Console( "Start container response: " + t )()
          }

          response.error = false
          response.id = res.Id
        }
      }
    }]
    [kill( id )( response ) {
      scope(err) {
        install(
          TypeMismatch => {
            handle_error
          },
          InvocationFault => {
            handle_error
          },
          IOException => {
            handle_error
          },
          Timeout => {
            handle_error
          }
        )
        if(p.debug) {
          println@Console( "Killing: " + id )()
        }
        stopContainer@Jocker({
          id = id
          t = 1
        })()
        removeContainer@Jocker({
          id = id
          force = true
        })()
        response.error = false
      }
    }]
  }
}
