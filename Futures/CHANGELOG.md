# Changelog

## 0.7

First release of `Carlos Futures` as a separate framework.

**Breaking changes**
- As documented in the `MIGRATING.md` file, you will have to add a `import CarlosFutures` line everywhere you make use of Carlos' `Future`s or `Promise`s.

**New features**
- It's now possible to compose async functions and `Future`s through the `>>>` operator.
- The implementation of `ReadWriteLock` taken from [Deferred](https://github.com/bignerdranch/Deferred) is now exposed as `public`.
- It's now possible to take advantage of the `GCD` struct to execute asynchronous computation through the functions `main` and `background` for GCD built-in queues and `async` for GCD serial or custom queues.

**Improvements**
- `Promise`s are now safer to use with GCD and in multi-thread scenarios.

**Fixes**
- Fixes a bug where calling `succeed`, `fail` or `cancel` on a `Promise` or a `Future` didn't correctly release all the attached listeners.