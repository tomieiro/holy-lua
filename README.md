# Lua para HolyC / TempleOS

Este projeto porta o interpretador Lua 5.4.9 para HolyC, com integração ao
TempleOS. O objetivo não é apenas traduzir a sintaxe do C: é preservar a
semântica da VM Lua enquanto substituir, de forma explícita, os serviços que
normalmente vêm da libc e de um sistema POSIX.

## Estado atual

O snapshot original do Lua está em `src/lua/` e continua sendo a referência
de comportamento. O build host está funcional e a primeira camada HolyC já
compila com `hcc`. A VM completa ainda está em processo de conversão: a
entrada `src/templeos/lua.hc` e a interface em
`src/platform/templeos/templeos_api.hc` são a fundação da integração, não uma
afirmação de que todos os subsistemas já executam no TempleOS.

## Por que existe uma camada de plataforma

O Lua original depende de várias interfaces que não devem ser espalhadas pelo
port:

- `malloc`, `realloc`, `free`: memória dinâmica;
- `setjmp` e `longjmp`: recuperação de erros não-locais;
- `FILE*`, `stdio` e `readline`: console e arquivos;
- `time`, `clock` e funções de calendário;
- `dlopen`, `dlsym` e `dlclose`: bibliotecas dinâmicas;
- sinais, locale, tipos da libc e formatação numérica.

Em TempleOS, essas responsabilidades devem conversar com as APIs HolyC,
como `MAlloc`, `Free`, `MemCpy`, `FileRead`, `FileWrite`, `Print` e os
contadores de tempo do sistema. A fronteira inicial está concentrada em
`src/platform/templeos/templeos_api.hc`. Conforme a VM for portada, o código
do runtime deve depender dessa fronteira, e não chamar diretamente APIs
POSIX.

## Organização do repositório

```text
src/lua/                         Lua 5.4.9 original
src/platform/templeos/           adaptação dos serviços de sistema
src/templeos/                    entradas e programas .hc
tests/lua/testes/                suíte de testes Lua
docs/                            decisões e estado do port
build/                           artefatos locais, ignorados pelo Git
AICP.aicp                        mapa semântico para agentes
Makefile                         comandos de desenvolvimento
```

Os nomes de arquivo novos usam extensões minúsculas. O include `tos.HH` é a
única referência com extensão maiúscula porque é o nome fornecido pelo
`hcc`; ele não pertence ao código deste repositório.

## Requisitos

Para o build host, são necessários GCC ou Clang, Make e as bibliotecas de
matemática, `dl` e readline disponíveis no sistema.

Para validar HolyC localmente, este projeto usa o compilador `hcc`. A versão
testada durante o desenvolvimento foi `hcc v0.0.15-beta`, que fornece
`/usr/local/include/tos.HH`. Esse `hcc` é um compilador HolyC para o host; a
validação final contra o kernel e as convenções do TempleOS deve também ser
feita dentro de uma instalação/imagem TempleOS.

## Comandos

```sh
# Compila o interpretador original no host.
make host

# Executa a entrada principal da suíte Lua no host.
make test

# Prepara os arquivos HolyC em build/templeos/.
make templeos-prepare

# Remove artefatos locais.
make clean
```

Para verificar diretamente a camada HolyC com o `hcc`:

```sh
mkdir -p build/hcc
hcc -c -o build/hcc/lua-platform.o \
  src/platform/templeos/templeos_api.hc
hcc -c -o build/hcc/lua-entry.o src/templeos/lua.hc
```

O `Makefile` host não tenta fingir que existe um cross-compiler TempleOS.
`make templeos-prepare` apenas coleta os `.hc`; a compilação integrada ao
TempleOS fica deliberadamente separada do build C host.

## Estratégia de port

A ordem recomendada é:

1. alinhar tipos, limites e configuração em `luaconf.h` e `llimits.h`;
2. ligar `lmem.c` a `LuaPlatformAlloc`, `LuaPlatformRealloc` e
   `LuaPlatformFree`;
3. substituir o mecanismo de erro de `ldo.c` por uma solução HolyC;
4. portar console, leitura de código e arquivos de `lua.c`, `liolib.c` e
   `loadlib.c`;
5. converter a VM, o GC, o parser e as estruturas internas;
6. reintroduzir bibliotecas padrão uma por vez;
7. expor a API própria de extensões HolyC;
8. executar os testes de conformidade no TempleOS.

O comportamento do Lua original é o oráculo: cada mudança de runtime deve
continuar passando o build/teste host quando aplicável e deve ganhar um teste
específico quando a diferença for intencional para TempleOS.

## API de extensões HolyC

A API pública ainda será definida depois que o estado e o ciclo de vida do
runtime estiverem estáveis. A direção prevista é oferecer funções HolyC para:

- criar e destruir um estado Lua;
- carregar/avaliar um buffer ou arquivo;
- empilhar e ler números, strings, booleanos e userdata;
- registrar tabelas de funções HolyC;
- propagar erros Lua sem depender de `setjmp` da libc.

Essa API deve ser pequena, documentada e independente dos detalhes internos
de `src/lua/`, permitindo que programas TempleOS usem Lua sem conhecer a VM.

## Contribuindo

Não altere silenciosamente o snapshot de referência para resolver um problema
de plataforma. Primeiro coloque a adaptação em `src/platform/templeos/`,
documente a diferença em `docs/port-status.md` e adicione uma verificação
reproduzível. Commits devem ser pequenos e separar reorganização, build,
camada de plataforma e alterações da VM.

Please **do not** send pull requests. To report issues, post a message to the [Lua mailing list](https://www.lua.org/lua-l.html).

Download official Lua releases from [Lua.org](https://www.lua.org/download.html).
