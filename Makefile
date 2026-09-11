# Lua / HolyC port
# The host build is the reference build; TempleOS sources are compiled there.

CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -std=c99
CPPFLAGS += -Isrc/lua -DLUA_USE_LINUX -DLUA_USE_READLINE
BUILD := build/host
BIN := $(BUILD)/lua

SRC := $(filter-out src/lua/lua.c src/lua/ltests.c src/lua/onelua.c,$(wildcard src/lua/*.c))
OBJ := $(patsubst src/lua/%.c,$(BUILD)/%.o,$(SRC))

.PHONY: all host test templeos-prepare clean

all: host
host: $(BIN)

$(BIN): $(BUILD)/lua.o $(OBJ)
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -Wl,-E -o $@ $^ -lm -ldl -lreadline

$(BUILD)/%.o: src/lua/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

test: host
	$(MAKE) -C tests/lua/testes/libs LUA_DIR=../../../../src/lua
	cd tests/lua/testes && ../../../$(BIN) main.lua

templeos-prepare:
	@mkdir -p build/templeos
	cp src/templeos/*.hc build/templeos/
	cp src/platform/templeos/*.hc build/templeos/

clean:
	rm -rf build
