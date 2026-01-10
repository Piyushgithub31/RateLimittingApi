namespace RateLimittingApi.ConfigModels
{
    public class RateLimitOptions
    {
        public int PermitLimit { get; set; } = 10;

        public int TimeWindow { get; set; } = 60;
    }
}
