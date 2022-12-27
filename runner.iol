type RunRequest {
  name: string
  data: undefined
}
type RunResponse { data: undefined }

interface RunnerAPI {
  RequestResponse:
    run( RunRequest )( RunResponse )
}
