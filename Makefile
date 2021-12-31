test: fmt init validate

i init:
	terraform init

u upgrade:
	terraform init -upgrade

v validate:
	terraform validate

f fmt:
	terraform fmt -recursive

vagrant-start:
	cd vagrant/master && ./start
	cd vagrant/infra && ./start
	cd vagrant/app && ./start

vagrant-test: fmt init validate
	terraform apply -auto-approve

vagrant-stop:
	cd vagrant/master && vagrant destroy
	cd vagrant/infra && vagrant destroy
	cd vagrant/app && vagrant destroy
