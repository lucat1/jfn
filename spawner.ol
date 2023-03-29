from console import Console
from runtime import Runtime
from string_utils import StringUtils
from .jocker import InterfaceAPI

type SpawnRunnerRequest {
  name: string
}

interface SpawnerAPI {
  RequestResponse:
    spawnRunner( SpawnRunnerRequest )( void ),
}

service Spawner {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed StringUtils as StringUtils

  outputPort Jocker {
    Location: "socket://localhost:8008"
    protocol: sodep
    Interfaces: InterfaceAPI
  }

  inputPort SumInput {
    location: "local"
    protocol: sodep
    interfaces: SpawnerAPI
  }

  init {
    getenv@Runtime( "JOCKER_LOCATION" )( Jocker.location )
    getenv@Runtime( "DOCKER_NETWORK" )( global.network )
  }

  main {
    [spawnRunner( request )() {
      networks[0] = global.network
      createContainer@Jocker({
        name = request.name
        Hostname = request.name
        NetworkSettings = {
          Networks << networks
        }
      })(res)
      valueToPrettyString@StringUtils( res )( t )
      println@Console( "Create container ans: " + t )()
    }]
  }
}
