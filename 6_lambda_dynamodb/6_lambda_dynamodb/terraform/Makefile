venv: venv/bin/activate
venv/bin/activate: requirements.txt
	test -d venv || virtualenv -p python3.12 venv
	venv/bin/pip3 install -Ur requirements.txt
	touch venv/bin/activate

clean:
	rm -rf venv
	rm -rf package
	rm -f lambda_function.zip
	rm -rf src/ingest/package
	rm -f src/ingest/lambda_function.zip
	rm -rf src/query/package
	rm -f src/query/lambda_function.zip

ingest: clean
	cd src/ingest && bash ../../deploy.sh iot_ingest_lambda

query: clean
	cd src/query && bash ../../deploy.sh iot_query_lambda

clean-terraform:
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate terraform.tfstate.backup
	rm -f *.tfplan
