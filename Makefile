.PHONY: verify-foundation verify-foundation-local containers-build containers-doctor agents agents-validate verify
.PHONY: start-frontend start-backend start-android start-all mvp-up mvp-down mvp-logs

start-frontend:
	python3 -B scripts/start_agent.py frontend

start-backend:
	python3 -B scripts/start_agent.py backend

start-android:
	python3 -B scripts/start_agent.py android

start-all:
	python3 -B scripts/start_agent.py all

mvp-up:
	python3 -B scripts/mvp.py up

mvp-down:
	python3 -B scripts/mvp.py down

mvp-logs:
	python3 -B scripts/mvp.py logs

verify-foundation:
ifeq ($(TRAGO_CONTAINER),1)
	$(MAKE) verify-foundation-local
else
	python3 -B scripts/podman_env.py run --execute -- make verify-foundation-local
endif

verify-foundation-local:
	python3 -B -m unittest discover -s tests -v
	python3 -B scripts/agents.py validate

containers-build:
	python3 -B scripts/podman_env.py build

containers-doctor:
	python3 -B scripts/podman_env.py doctor

agents:
	python3 -B scripts/agents.py list

agents-validate:
	python3 -B scripts/agents.py validate

verify:
	@echo 'Verificação completa do SaaS ainda não implementada. Use make verify-foundation para o controlador local.'
	@exit 2
