test: fmt init validate

i init:
	terraform init

u upgrade:
	terraform init -upgrade

v validate:
	terraform validate

f fmt:
	terraform fmt -recursive

