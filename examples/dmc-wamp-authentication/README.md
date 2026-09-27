# dmc-wamp-authentication

Joins a realm that requires a login, answers the router's challenge (WAMP-CRA) or sends a ticket, and calls `com.example.add2`.

1. Start the router in [`../router/`](../router/README.md); its `/auth` path requires a login.
2. In `app_config.lua`, choose the user (`Config.user = user_1` for `joe`, `user_2` for `peter`, whose key is salted) and the method (`authmethods`: `{ 'wampcra' }` or `{ 'ticket' }`). To use a router on another computer, change `host`.
3. Open `main.lua` in the Solar2D Simulator. WAMP-CRA uses Solar2D's `crypto` library, so the example doesn't run outside Solar2D.

The expected output is in the [examples README](../README.md#authentication); how authentication works is in the [API reference](../../docs/api.md#authentication).
