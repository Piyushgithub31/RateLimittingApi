# RateLimittingApi

## Project Overview
A small ASP.NET Core Web API that enforces per-identifier rate limiting using an in-memory fixed-window counter. The API exposes a single endpoint to check whether a request from a client identifier is allowed under the configured rate-limiting policy.

## Setup and Execution
Prerequisites:
- .NET 8 SDK installed (C# 12 targets .NET 8)

Build and run locally:
1. Restore and build the projects from the repository root:

   `dotnet build`

2. Run the API (from repo root):

   `dotnet run --project ./RateLimittingApi/RateLimittingApi.csproj`

   By default the app will start on the Kestrel port(s) configured by ASP.NET Core. Swagger UI is available in Development environment.

Configuration:
- The rate limiting options are bound to the `RateLimiting` section in `appsettings.json` which maps to the `RateLimitOptions` class (`ConfigModels/RateLimitOptions.cs`). The application expects the following properties under `RateLimiting`:
  - `PermitLimit` (int) — number of allowed requests per window.
  - `TimeWindow` (int) — window size in seconds.

  Note: `appsettings.json` shipped in the repository currently uses the key `WindowSeconds`. Update it to `TimeWindow` if you want the configured value to be picked up by `RateLimitOptions` as implemented.

Running tests:

`dotnet test ./RateLimmittingApi.Tests/RateLimmittingApi.Tests.csproj`

The test project contains unit tests for the in-memory fixed-window store (`Service/InMemoryFixedWindowRateLimitStore.cs`).

## API Documentation
Endpoint: `POST /check`

- Request body (JSON):
  - `id` (string) — identifier for the client/requester to be checked.

Example request (curl):

`curl -X POST https://localhost:5001/check -H "Content-Type: application/json" -d '{"id":"client-1"}' -k`

Responses:
- `200 OK` — request allowed.
- `429 Too Many Requests` — request blocked. Response includes `Retry-After` header containing the configured window length in seconds.

Example success response:
- Status: `200 OK`

Example rate-limited response:
- Status: `429 Too Many Requests`
- Header: `Retry-After: 60`

## Design Decisions & Trade-offs
- Algorithm chosen: Fixed-window counter.
  - Why: simple to implement and easy to reason about; suitable for the exercise and small-scale usage.
  - How it works: for each identifier we keep a counter and a window start timestamp. Requests increment the counter until `PermitLimit` is reached. When the time window expires the counter resets.

- Code structure:
  - `Controllers/RateLimitController.cs` — HTTP endpoint that accepts `CheckRequest` and returns 200 or 429.
  - `Service/RateLimitService.cs` — orchestration layer that reads configuration and delegates to the store.
  - `Service/InMemoryFixedWindowRateLimitStore.cs` — the in-memory implementation of the store implementing `IInMemoryRateLimitStore`.
  - `Interfaces/IInMemoryRateLimitStore.cs` and `Interfaces/IRateLimitService.cs` — abstractions used to decouple implementation details and enable DI-based replacement.
  - `ConfigModels/RateLimitOptions.cs` — configuration POCO bound from `appsettings.json`.

- Concurrency & correctness:
  - A `ConcurrentDictionary` stores counters per identifier. Each `RateLimitCounter` is locked when being updated to ensure correct increments and window resets. This keeps the implementation simple while avoiding race conditions per key.

- Trade-offs made:
  - Simplicity vs accuracy: fixed-window counters are subject to boundary effects (bursting at window edges).
  - Memory vs durability: storing counters in memory is simple and fast but not durable or shared across multiple instances.
  - Performance vs global locking: we avoid global locking by locking per counter instance. This provides good concurrency for different identifiers but still serializes ops for the same identifier.

- Replacing the in-memory store:
  - The store is abstracted behind `IInMemoryRateLimitStore` and registered in DI in `Program.cs`:

    `builder.Services.AddSingleton<IInMemoryRateLimitStore, InMemoryFixedWindowRateLimitStore>();`

  - To replace it, implement `IInMemoryRateLimitStore` (for example a Redis-backed store), and register your implementation in DI.

- Improvements given more time:
  - Add more comprehensive tests including concurrency tests and integration tests.
  - Fix configuration key mismatch between `appsettings.json` and `RateLimitOptions` or add binding/aliasing.
  - Logging for monitoring behavior.

## Notes
- The codebase is intentionally small and focused on demonstrating rate-limiting fundamentals.