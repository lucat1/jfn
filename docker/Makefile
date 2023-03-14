all: function_catalog gateway runner provisioner

provisioner: Dockerfile.runner ../runner.ol runner_params.json
	docker buildx build -t jfn/runner -f Dockerfile.runner ..

gateway: Dockerfile.provisioner ../provisioner.ol provisioner_params.json
	docker buildx build -t jfn/provisioner -f Dockerfile.provisioner ..

runner: Dockerfile.runner ../runner.ol runner_params.json
	docker buildx build -t jfn/runner -f Dockerfile.runner ..

function_catalog: Dockerfile.function_catalog ../function_catalog.ol function_catalog_params.json
	docker buildx build -t jfn/function_catalog -f Dockerfile.function_catalog ..
