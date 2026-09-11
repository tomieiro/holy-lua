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
a variável de controle do `for`), sem valores não numéricos. O `hcc` v0.0.15 compara `F64` incorretamente com literais inteiros
(`step > 0`) e tipa comparações `F64` como `F64`; o código usa `0.0` e
desvios explícitos para contornar isso.

O núcleo também aceita `elseif` encadeado e `break` dentro de `while`/`for`.
Condições de `elseif` posteriores a um ramo já escolhido são analisadas em modo
de salto. `break` fora de laço lança o erro 24.

Variáveis agora seguem o escopo léxico de Lua: `local` cria uma ligação no
bloco atual (podendo sombrear nomes externos) e é descartada ao fim do bloco;
atribuição sem `local` altera o local visível mais interno ou, na ausência
dele, uma global. A variável de controle do `for` é local ao corpo do laço.
Há até 16 locais vivos e 16 globais.

O operador `%` foi adicionado com a semântica de módulo floor de Lua (o
resultado tem o sinal do divisor, ex.: `-1 % 5 == 4`), com a mesma precedência
de `*` e `/`.

`repeat ... until condição` executa o corpo ao menos uma vez e repete
enquanto a condição for falsa. Diferente do Lua real, a condição do `until`
não enxerga locais declarados no corpo: `LuaMiniSubBlock` já os descarta ao
final do corpo antes da condição ser avaliada.

`goto nome` e `::nome::` também são suportados. Cada bloco (`LuaMiniBlock`)
mantém sua própria tabela de rótulos já vistos; um `goto` ativo desce a
pilha de blocos correspondendo ao fluxo de execução real, primeiro
procurando o rótulo no bloco atual (para trás, na tabela, ou para frente,
continuando a busca em modo de salto) e, se não encontrado, propaga para o
bloco chamador. Um rótulo nunca encontrado lança o erro 27. Diferente do
Lua real, esta implementação não impede um `goto` de saltar para dentro do
escopo de um bloco não executado (`if`/`elseif`/`else` não tomado) alcançado
apenas como alvo do salto — a restrição de escopo do Lua real não é
verificada.

Descoberta durante a depuração deste milestone: a mensagem de diagnóstico
`uncaught throw: N` do `hcc` v0.0.15 imprime o código lançado em
**hexadecimal**, não decimal (`throw(17)` aparece como `11`). Não é um bug;
é fácil de interpretar mal ao depurar um `throw` não capturado.

## Valores gerais: nil, boolean, number, string

O núcleo mínimo deixou de operar só sobre `F64`. `LuaMiniValue` é um struct
com uma tag (`nil`/`boolean`/`number`/`string`) e um buffer de string inline
de 63 bytes (sem alocação em heap; ainda não integrado ao `LuaString`
referência-contada de `lua_string.hc`). `LuaMiniExpression`,
`LuaMiniPrimary`, `LuaMiniLookup`, `LuaMiniDeclare`/`LuaMiniAssign` e o
resultado de `return` agora carregam `LuaMiniValue`, não `F64`.

Para preservar os testes existentes, a API pública `F64`
(`LuaMiniEval`/`LuaMiniRun`/`*WithRegistry`) continua existindo: ela chama a
nova implementação que retorna `LuaMiniValue` e converte o resultado para
número (lançando erro 28 se não for um número). Quem precisa do valor bruto
usa as novas `LuaMiniEvalValue`/`LuaMiniRunValue`/`*WithRegistryValue`.

Novidades da linguagem cobertas:

- literais `"string"` (com `\n`, `\t`, `\\`, `\"` e qualquer outro escape
  passando literal), `true`, `false`, `nil`;
- `..` para concatenação (mesma precedência de `+`/`-`; formata números como
  o Lua real — sem ponto decimal quando são inteiros, até 6 casas depois);
- `#valor` e `len(valor)` agora aceitam qualquer expressão que produza uma
  string, não só um literal;
- `print(valor)` e `type(valor)` como novas funções embutidas de um
  argumento;
- **comandos de chamada isolados**: `print(x)` sozinho numa linha agora
  funciona como comando (antes só existia dentro de uma expressão);
- `==`/`~=`/`<`/`<=`/`>`/`>=` viraram uma camada de expressão geral
  (`LuaMiniComparison`), utilizável em qualquer lugar onde um valor é
  esperado (`x = a == b`, `return a < b`), não só dentro de `if`/`while`/
  `until`;
- `if`/`while`/`until` agora aceitam qualquer expressão como condição
  (truthiness: só `nil` e `false` são falsos, como no Lua real), não
  apenas uma comparação;
- `and`/`or` com curto-circuito real: o lado não avaliado ainda é
  analisado (para manter a posição do parser correta) mas em modo de
  salto, então chamadas nativas do lado descartado não executam; cada
  operador retorna o valor do operando, não um booleano genérico
  (`nil or 7` é `7`; `3 or 7` é `3`).

Limitações que continuam: sem tabelas, sem funções definidas em Lua
(closures), sem coerção número↔string automática em comparações
(`1 == "1"` é `false`), sem `elseif`/`local function`, nomes ainda vivem
num escopo plano com no máximo 16 locais e 16 globais.

### Dois bugs novos do `hcc` v0.0.15 encontrados neste milestone

1. **`return F();` derruba o JIT quando `F` retorna um struct grande**
   (como `LuaMiniValue`, que carrega um array de 64 bytes). O segfault
   acontece mesmo no caso mais simples (`LuaMiniValue F() { return G(); }`),
   independente de a função ter parâmetros por ponteiro. A correção é
   sempre materializar o resultado numa variável local antes de retornar:
   `LuaMiniValue v = G(); return v;`. Todo o arquivo foi auditado e corrigido
   para esse padrão.
2. **`return` de um literal inteiro ou variável `I64` numa função `F64`
   devolve 0 silenciosamente**, sem erro de compilação — o valor é
   descartado em vez de convertido (`F64 F() { return 3; }` retorna `0.0`).
   A correção é usar um literal float explícito (`return 3.0;`) ou um cast
   postfixo (`return x(F64);`). Isso é mais amplo do que o bug de
   comparação `F64` vs. literal inteiro já documentado antes.

Ambos foram descobertos por bisecção manual com `hcc -jit` sobre programas
mínimos, já que o segfault não deixa nenhuma mensagem de diagnóstico.

## Funções definidas em Lua, com recursão real

`function nome(a, b) ... end` agora é suportado, incluindo recursão de
verdade (`fact(10)`, `fib(15)` testados). A declaração só registra o nome,
a posição do corpo no texto-fonte e os nomes dos parâmetros
(`LuaMiniFunctionDef`); o corpo em si é varrido em modo de salto na
declaração (sem executar) e só é de fato interpretado a cada chamada.

Uma chamada (`LuaMiniCallFunction`) salva posição, contagem de locais,
`returned`/`breaking`/`jumping`/`loop_depth`/resultado do parser, pula o
cursor para a posição salva do corpo, declara os parâmetros como locais
novos (argumentos faltantes viram `nil`), roda o bloco, captura o valor de
`return` (ou `nil` se não houve `return`) e restaura tudo antes de
retornar ao ponto de chamada. A recursão é recursão de C de verdade,
através de `LuaMiniCallFunction`/`LuaMiniBlock`/`LuaMiniStatement`/
`LuaMiniPrimary` — não há pilha de chamadas própria da VM.

Chamadas aceitam múltiplos argumentos separados por vírgula (até 8),
diferente das funções embutidas de um argumento (`abs`/`sqrt`/`len`/
`print`/`type`/nativas registradas), que continuam como estão.

Como as funções vivem no mesmo array plano de locais usado por blocos e
laços, o array de locais cresceu de 16 para 64 posições — cada quadro de
chamada consome um slot por parâmetro e só é liberado quando a chamada
retorna, então essa é a limitação prática de profundidade de recursão
(não o limite de 200 do contador `call_depth`, que na prática nunca é
alcançado primeiro).

Chamar um nome não reconhecido (`nem_função_nem_nativa()`) agora lança o
erro 12 de forma limpa, mesmo sem argumentos — antes disso caía sem querer
na análise de "número inválido" ao tentar interpretar o `)` vazio como uma
expressão.

Limitações que continuam: sem tabelas, sem closures/upvalues (uma função
só enxerga globais e seus próprios parâmetros/locais, nunca locais de um
escopo pai), sem `local function`, sem múltiplos valores de retorno, sem
`elseif` dentro de expressões, sem coerção número↔string em comparações.

Um terceiro bug do `hcc` v0.0.15 apareceu neste milestone: `&&` rejeita um
operando que seja um ponteiro puro (ou uma negação `!ponteiro`)
encadeado com mais termos `&&` (`"cannot be applied to a pointer type"`).
A correção é comparar explicitamente com `NULL`
(`ponteiro != NULL && ...`); um `!ponteiro` isolado, fora de `&&`, funciona
normalmente.
