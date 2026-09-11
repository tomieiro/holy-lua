/* Non-local error boundary for the HolyC Lua runtime. */

#include "templeos_api.hc"

/* Lua uses positive status values for errors and LUA_YIELD for suspension. */
#define LUA_PLATFORM_OK 0

U0 LuaPlatformThrow(I64 status) {
  throw(status);
}

I64 LuaPlatformRunProtected(U0 (*function)(U0 *userdata), U0 *userdata) {
  I64 status;

  status = LUA_PLATFORM_OK;
  try {
    function(userdata);
  } catch {
    status = Fs->except_ch;
  }
  return status;
}
