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

O pool de strings em `lua_string.hc` reaproveita strings iguais por hash e
conteúdo, mantém uma referência própria e a libera no encerramento. A raiz do
pool ainda precisa ser incorporada ao GC definitivo do runtime.

O pool também faz sweep de strings com apenas a referência-base do próprio
pool. O smoke test cobre a coleta de uma string temporária e a preservação da
string usada como chave de tabela; raízes completas de stack/tabelas ainda
serão reunidas em um GC geral.

`src/platform/templeos/lua_gc.hc` reúne as raízes de estado/tabela e expõe a
coleta do pool. Nesta etapa, a segurança vem do ownership por referências; a
marcação completa de todos os objetos Lua ainda será necessária para suportar
ciclos, userdata e closures.

`src/platform/templeos/lua_call.hc` adiciona closures nativas, frames
empilháveis e chamada protegida. A closure escreve o número de resultados por
parâmetro de saída; essa ABI evita a incompatibilidade observada no `hcc` com
retornos de função através de ponteiros. O smoke test está em
`tests/holyc_call.hc`.

O primeiro núcleo executável está em `src/platform/templeos/lua_mini.hc`: ele
avalia literais numéricos, variáveis locais, atribuições, `return`, chamadas básicas (`abs`, `sqrt`, `len`), parênteses e `+ - * /` com precedência,
incluindo erros protegidos por `throw`. `tests/holyc_mini.hc` executa esse
fluxo ponta a ponta com `hcc -jit`. Ainda não é a VM Lua completa; é o núcleo
funcional sobre o qual serão adicionados variáveis, chamadas e bytecode.

O núcleo também suporta a forma limitada `if condição then return expr end`
e `if condição then return expr else return expr end`, com comparações
numéricas `<`, `>` e `==`.

Funções HolyC podem ser expostas ao núcleo por `LuaMiniRegistry`. Cada entrada
associa um nome a uma função com a ABI `U0 func(F64 argumento, F64 *resultado)`;
o resultado por parâmetro de saída evita o problema de retorno de funções
através de ponteiros observado no `hcc`. `LuaMiniEvalWithRegistry` e
`LuaMiniRunWithRegistry` aceitam o registro sem alterar as APIs de conveniência
existentes. O registro é deliberadamente pequeno e estático nesta etapa;
argumentos múltiplos, valores Lua gerais e closures completas continuam sendo
trabalho do port principal.

`LuaMiniRun` agora executa blocos de comandos: `if ... then ... else ... end`
aninhados, `while condição do ... end`, `for i = início, limite[, passo] do
... end` e `return` em qualquer ponto, além de `local` opcional e das
comparações `<`, `<=`, `>`, `>=`, `==` e `~=`. Blocos não executados são
analisados em modo de salto, sem atribuições, chamadas nativas ou erros de
nome/divisão. As variáveis continuam num escopo plano de oito nomes (inclusive
a variável de controle do `for`), sem `elseif`, `break` ou valores não
numéricos. O `hcc` v0.0.15 compara `F64` incorretamente com literais inteiros
(`step > 0`) e tipa comparações `F64` como `F64`; o código usa `0.0` e
desvios explícitos para contornar isso.
