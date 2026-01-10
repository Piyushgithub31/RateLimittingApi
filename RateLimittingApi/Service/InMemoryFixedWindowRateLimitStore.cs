using RateLimittingApi.Interfaces;
using RateLimittingApi.Models;
using System.Collections.Concurrent;

namespace RateLimittingApi.Service
{
    public class InMemoryFixedWindowRateLimitStore : IInMemoryRateLimitStore
    {
        private readonly ConcurrentDictionary<string, RateLimitCounter> _counterKeyValuePairs = new ConcurrentDictionary<string, RateLimitCounter>();
        public bool TryConsume(string identifier, int maxRequests, TimeSpan windowDuration)
        {
            var currentDateTime = DateTime.UtcNow;
            var requestCounter = _counterKeyValuePairs.GetOrAdd(identifier, _ => new RateLimitCounter { WindowStartUtc = currentDateTime, Count = 0 });

            lock (requestCounter) 
            {
                if (currentDateTime - requestCounter.WindowStartUtc >= windowDuration)
                {
                    requestCounter.WindowStartUtc = currentDateTime;
                    requestCounter.Count = 0;
                }

                if (requestCounter.Count >= maxRequests)
                {
                    return false;
                }

                requestCounter.Count++;
                return true;
            }
        }
    }
}
