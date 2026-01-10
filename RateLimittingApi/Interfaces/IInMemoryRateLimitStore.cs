namespace RateLimittingApi.Interfaces
{
    public interface IInMemoryRateLimitStore
    {
        bool TryConsume(string identifier, int maxRequests, TimeSpan windowDuration);
    }
}
