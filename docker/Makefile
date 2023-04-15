all: function_catalog provisioner gateway runner singleton

function_catalog: Dockerfile.function_catalog ../function_catalog.ol ../function_catalog_loader.ol
	docker buildx build -t jfn/function_catalog -f Dockerfile.function_catalog ..

provisioner: Dockerfile.provisioner ../provisioner.ol ../provisioner_loader.ol
	docker buildx build -t jfn/provisioner -f Dockerfile.provisioner ..

gateway: Dockerfile.gateway ../gateway.ol ../gateway_loader.ol
	docker buildx build -t jfn/gateway -f Dockerfile.gateway ..

runner: Dockerfile.runner ../runner.ol ../runner_loader.ol
	docker buildx build -t jfn/runner -f Dockerfile.runner ..

singleton: Dockerfile.singleton ../singleton.ol ../singleton_loader.ol
	docker buildx build -t jfn/singleton -f Dockerfile.singleton ..
