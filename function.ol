type FunctionRequest  { data: undefined }
type FunctionResponse { data: undefined }

interface FunctionAPI {
  RequestResponse:
    fn( FunctionRequest )( FunctionResponse )
}

