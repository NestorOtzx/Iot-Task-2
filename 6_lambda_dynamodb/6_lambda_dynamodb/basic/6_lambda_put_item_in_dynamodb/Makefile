venv: venv/bin/activate
venv/bin/activate: requirements.txt
	test -d venv || virtualenv -p python3.12 venv
	venv/bin/pip3 install -Ur requirements.txt
	touch venv/bin/activate

clean:
	rm -rf venv
	rm -rf package
	rm -rf lambda_function.zip

delete-lambda:
	aws lambda delete-function --function-name lambda_put_dynamodb
	@echo "Lambda lambda_put_dynamodb eliminada exitosamente."

deploy: clean
	bash ./deploy.sh lambda_put_dynamodb
