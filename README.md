# Lua para HolyC

Port experimental do interpretador Lua 5.4.9 para HolyC, com integração ao
TempleOS.

O código original permanece em `src/lua/` e serve como referência para o
comportamento da VM. A adaptação de memória, erros, console, arquivos e
bibliotecas fica em `src/platform/templeos/`; as entradas HolyC ficam em
`src/templeos/`.

## Desenvolvimento

```sh
make host
make test
make templeos-prepare
```

O build host é usado para regressão. O build TempleOS deve ser compilado
dentro do TempleOS com o compilador HolyC.

Please **do not** send pull requests. To report issues, post a message to the [Lua mailing list](https://www.lua.org/lua-l.html).

Download official Lua releases from [Lua.org](https://www.lua.org/download.html).
