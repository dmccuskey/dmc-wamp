# Changelog

## 1.1.0 (2026-10-01)

### Fixed

- Errors from the router reach their handler. An `ERROR` message (a call to a procedure nobody offers, a refused registration, permission denied) used to be misread as a protocol error, which closed the connection. Now the handler of the failed call, subscribe, unsubscribe, publish, register or unregister gets its event with `event.is_error` and `event.error` (`error.error` is the WAMP error URI, `error.message` the router's message).
- `publish()` with a `callback` gets `ONPUBLISHED` once the router has accepted the publication (`event.publication.id`): the acknowledgment option now reaches the router.
- Call options reach the router: `timeout`, and `receive_progress` for `ONPROGRESS` events (which also crashed).
- `unregister()` works (it called `unsubscribe()` on the registration).
- A lost connection no longer crashes the app: when the router stops, the network drops or the app calls `close()` while the realm is joined, the listener gets `ONDISCONNECT` with the reason `'wamp.close.transport_lost'`, and pending calls and requests get an error event. A `GOODBYE` from the router (such as a shutdown) crashed too.
- A router that can't be reached gives `ONERROR`, then `ONDISCONNECT` (no event before). A connection failed for an error now ends the session too.
- A registered procedure can return a plain value (the single result) or nothing; a table with only `results` and/or `kwresults` works as before. A procedure that raises an error sends a WAMP error to the caller (`wamp.error.runtime_error`, or the URI of a raised `Wamp.ApplicationError`) instead of leaving the call unanswered. A procedure registered on an object returns its result.
- A call with a timeout no longer breaks the callee's connection (the timeout in the invocation was checked as a boolean).
- `register()` with `pkeys` or `disclose_caller` works (it used an undefined `Types`), and sends them under the WAMP names.
- `is_connected` is `true` only while the realm is joined.
- `close()` no longer reads an undefined global, and messages still arriving after it are dropped.
- The modules no longer set the globals `_extend` (lua_utils' `extend()` replaces the copy) or need the global `newClass`.
- The examples handle errors, the publish example reads the acknowledgment, the callee example waits for its registration, and the stale `dmc_objects`, `dmc_states_mix` and `dmc_utils` copies are gone.

### Added

- `register()` and `unregister()` take a `callback`, which gets `ONREGISTERED` or `ONUNREGISTERED` (or an error event).
- `ONCONNECT` when the WebSocket connection opens, `ONCHALLENGE` when the router asks for authentication, and `event.details` on `ONJOIN`.
- `Wamp.VERSION`, and `Wamp.ApplicationError` for a procedure to raise.
- Unit tests (messages, and a session driven through a stand-in transport), and `tests/run_unit.sh` to run them with plain Lua 5.1.

### Changed

- `publish()` asks the router for an acknowledgment only when it has a `callback`.
- Calling `call()`, `register()`, `unregister()`, `publish()` or `subscribe()` before the realm is joined raises a clear error.
- Rebuilt against the current dmc-corona-boot, DMC-Lua-Library, dmc-sockets and dmc-websockets (faster WebSocket masking).
