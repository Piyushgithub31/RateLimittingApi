namespace RateLimittingApi.Interfaces
{
    public interface IRateLimitService
    {
        Task<bool> CheckAccessAsync(string id, CancellationToken cancellationToken);
    }
}
