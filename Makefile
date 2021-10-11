deploy-common:
	DEPLOY_ENVIRONMENT=common pipenv run runway deploy
deploy-development:
	DEPLOY_ENVIRONMENT=dev pipenv run runway deploy
destroy-common:
	DEPLOY_ENVIRONMENT=common pipenv run runway destroy
destroy-development:
	DEPLOY_ENVIRONMENT=dev pipenv run runway destroy
deploy-prod:
	DEPLOY_ENVIRONMENT=prod pipenv run runway deploy
destroy-prod:
	DEPLOY_ENVIRONMENT=prod pipenv run runway deploy
