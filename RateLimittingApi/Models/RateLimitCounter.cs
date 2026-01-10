namespace RateLimittingApi.Models
{
    public class RateLimitCounter
    {
        public int Count { get; set; }

        public DateTime WindowStartUtc { get; set; }
    }
}
