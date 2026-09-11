# Status do port

O repositório agora separa o Lua original da integração TempleOS:

- `src/lua/`: Lua 5.4.9 original, usado como referência semântica;
- `src/platform/templeos/`: substituições de serviços do sistema;
- `src/templeos/`: entradas executáveis em HolyC;
- `tests/lua/`: testes Lua originais.

A primeira camada de adaptação está em `src/platform/templeos/templeos_api.hc`.
Ela concentra memória (`MAlloc`/`Free`), console (`Print`), arquivos
(`FileRead`/`FileWrite`) e relógio do TempleOS. O núcleo deve ser ligado a
essa interface em vez de espalhar chamadas TempleOS pelos arquivos da VM.

O primeiro componente de runtime HolyC está em
`src/platform/templeos/lua_memory.hc`. Ele encapsula alocação, realocação,
liberação e contabilidade de bytes vivos/alocações. Ele compila com `hcc`, mas
ainda não substitui o `frealloc` do `global_State` em `src/lua/lmem.c`.

O mecanismo HolyC de exceções está encapsulado em
`src/platform/templeos/lua_exceptions.hc`. A função protegida captura o
`I64` lançado. A integração com `luaD_rawrunprotected` ainda é o próximo
passo do port do runtime.

`src/platform/templeos/lua_runtime.hc` reúne a vida útil do runtime,
incluindo inicialização, allocator, chamadas protegidas e encerramento. O
entrypoint TempleOS usa esse owner; o próximo trabalho é substituir as
estruturas C de `lua_State`/`global_State` por estruturas HolyC equivalentes.

O checkout `../templeos` fornece o código-fonte e a documentação das APIs
HolyC, incluindo `MAlloc`, `Free`, `MemCpy`, `Print`, `FileRead`, `FileWrite`
e `cnts.jiffies`. Ele não contém neste workspace um compilador HolyC, uma
imagem bootável ou um artefato de execução; portanto a validação final dos
`.hc` ainda precisa ser feita dentro de uma instalação TempleOS.

`src/platform/templeos/lua_state.hc` é o primeiro núcleo de estado HolyC:
define tags básicos, `LuaValue` e uma pilha que cresce pelo allocator do
runtime. Ainda não representa a VM completa; strings, tabelas, closures,
frames e GC serão adicionados sobre essa base.

`src/platform/templeos/lua_table.hc` adiciona uma tabela hash de chaves
inteiras, com sondagem linear, rehash e operações de leitura/escrita. Ela é
uma etapa de infraestrutura; ainda não cobre chaves string, metatables,
arrays Lua ou coleta de lixo.

`src/platform/templeos/lua_string.hc` adiciona strings com comprimento
explícito, terminador NUL, hash e comparação por conteúdo. O objeto e seus
bytes são liberados pelo mesmo `LuaRuntime`; a integração das strings como
chaves de tabela e objetos rastreados pelo GC ainda está pendente.

`LuaString` agora tem contagem de referências. `LuaValue` retém e libera a
string ao ser atribuído, removido da stack ou encerrado. A tabela ainda usa
somente chaves inteiras; o próximo passo é aplicar o mesmo ownership às
entradas com chave string.

As tabelas agora aceitam também `LuaString` como chave. A busca usa hash e
comparação por conteúdo; a tabela retém a chave e os valores string e libera
ambos no fechamento. O comportamento básico é exercitado em
`tests/holyc_table.hc`.

## Ordem do port

1. tipos e configuração (`luaconf.h`, `llimits.h`);
2. memória (`lmem.c`): a API HolyC já existe, mas ainda precisa ser ligada
   ao `frealloc` usado pelo `global_State`;
3. erros não-locais (`ldo.c`);
4. console e arquivos (`lua.c`, `liolib.c`, `loslib.c`);
5. VM, GC, parser e bibliotecas;
6. API HolyC para extensões Lua;
7. testes de conformidade dentro do TempleOS.

O interpretador só será considerado portado quando a VM e os testes
essenciais executarem no TempleOS; os arquivos `.hc` atuais são a fronteira
inicial, não uma implementação simulada.
