all: function_catalog gateway runner

function_catalog: Dockerfile.function_catalog ../function_catalog.ol
	docker buildx build -t jfn/function_catalog -f Dockerfile.function_catalog ..

gateway: Dockerfile.gateway ../gateway.ol ../gateway_params.json
	docker buildx build -t jfn/gateway -f Dockerfile.gateway ..

runner: Dockerfile.runner ../runner.ol ../runner_params.json
	docker buildx build -t jfn/runner -f Dockerfile.runner ..
