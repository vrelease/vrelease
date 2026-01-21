.DEFAULT_GOAL := build

ARTIFACT = vrelease

ifeq ($(OS),Windows_NT)
	ARTIFACT = vrelease.exe
endif

NC = nimble
NFLAGS = --verbose --verbosity:2 -o:$(ARTIFACT) -d:ssl


.PHONY: tests
tests:
	@$(NC) tests

clean:
	@rm -rf $(ARTIFACT)

write-meta:
	@nim compile --run --hints:off -d:release writemeta.nim

build: clean
	@printf "\nVRELEASE BUILD\n"
	@printf "\n>>> parameters\n"
	@printf "* NC: %s (%s)\n" "$(NC)" "$(shell which $(NC))"
	@printf "* NFLAGS: %s\n" "$(strip $(NFLAGS))"
	@printf "* PATH:\n" "$(PATH)"
	@echo "$(PATH)" | tr ':' '\n' | xargs -n 1 printf "   - %s\n"
	@printf "\n"
	@printf "\n>>> write-meta\n"
	@$(MAKE) write-meta
	@printf "\n>>> compile\n"
	$(NC) build $(NFLAGS)
	@printf "\n* binary size: "
	@du -h $(ARTIFACT) | cut -f -1
	@printf "\nDONE\n"

release: NFLAGS += -d:release
release: build
	@strip $(ARTIFACT)
