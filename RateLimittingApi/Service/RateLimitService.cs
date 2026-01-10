using Microsoft.Extensions.Options;
using RateLimittingApi.ConfigModels;
using RateLimittingApi.Interfaces;

namespace RateLimittingApi.Service
{
    public class RateLimitService : IRateLimitService
    {
        private readonly IInMemoryRateLimitStore _store;
        private readonly IOptionsMonitor<RateLimitOptions> _options;

        public RateLimitService(IInMemoryRateLimitStore inMemoryRateLimitStore, IOptionsMonitor<RateLimitOptions> rateLimitOptions)
        {
            _store = inMemoryRateLimitStore;
            _options = rateLimitOptions;
        }

        public Task<bool> CheckAccessAsync(string id, CancellationToken cancellationToken)
        {
            var currentConfigValue = _options.CurrentValue;
            var window = TimeSpan.FromSeconds(currentConfigValue.TimeWindow);

            return Task.FromResult(_store.TryConsume(id,currentConfigValue.PermitLimit, window));
        }
    }
}
