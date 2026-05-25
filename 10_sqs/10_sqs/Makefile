.PHONY: deploy clean destroy test-lambda test-ecs

REGION = us-east-1
REPO_NAME = sqs-consumer-repo

venv: venv/bin/activate
venv/bin/activate: requirements.txt
	test -d venv || virtualenv -p python3.12 venv
	venv/bin/pip3 install -Ur requirements.txt
	touch venv/bin/activate

deploy:
	chmod +x build_and_deploy.sh
	./build_and_deploy.sh

clean:
	rm -rf terraform/.terraform/
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate*
	rm -f terraform/project.tfplan
	rm -f terraform/lambda_function.zip
	rm -rf venv


destroy:
	cd terraform && terraform destroy -auto-approve || echo "No se pudo destruir"
	$(MAKE) clean

test-lambda:
	@QUEUE_URL=$$(cd terraform && terraform output -raw lambda_queue_url) && \
	echo "Enviando mensaje de prueba a: $$QUEUE_URL" && \
	aws sqs send-message --queue-url "$$QUEUE_URL" --message-body "Mensaje de prueba automático para LAMBDA" --region $(REGION)

test-ecs:
	@QUEUE_URL=$$(cd terraform && terraform output -raw ecs_queue_url) && \
	echo "Enviando mensaje de prueba a: $$QUEUE_URL" && \
	aws sqs send-message --queue-url "$$QUEUE_URL" --message-body "Mensaje de prueba automático para ECS" --region $(REGION)
