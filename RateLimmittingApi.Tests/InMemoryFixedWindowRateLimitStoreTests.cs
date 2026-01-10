using RateLimittingApi.Service;

namespace RateLimmittingApi.Tests
{
    public class InMemoryFixedWindowRateLimitStoreTests
    {
        [Fact]
        public void TryConsume_AllowsRequestsUpToLimit_ThenBlocks()
        {
            //Arrange
            var store = new InMemoryFixedWindowRateLimitStore();
            var id = "client-1";
            var maxRequests = 3;
            var window = TimeSpan.FromSeconds(10);

            // Act & Assert
            for (var i = 0; i < maxRequests; i++)
            {
                Assert.True(store.TryConsume(id, maxRequests, window));
            }

            //Assert that the next request is blocked
            Assert.False(store.TryConsume(id, maxRequests, window));
        }

        [Fact]
        public void TryConsume_ResetsAfterWindowExpires()
        {
            //Arrange
            var store = new InMemoryFixedWindowRateLimitStore();
            var id = "client-reset";
            var maxRequests = 1;
            var window = TimeSpan.FromMilliseconds(100);

            //Act & Assert
            Assert.True(store.TryConsume(id, maxRequests, window));
            Assert.False(store.TryConsume(id, maxRequests, window));

            //Act & Assert after window expiration
            Thread.Sleep(window + TimeSpan.FromMilliseconds(50));
            Assert.True(store.TryConsume(id, maxRequests, window));
        }

        [Fact]
        public void TryConsume_UsesIndependentCountersPerIdentifier()
        {
            //Arrange
            var store = new InMemoryFixedWindowRateLimitStore();
            var idA = "client-A";
            var idB = "client-B";
            var maxRequests = 1;
            var window = TimeSpan.FromSeconds(10);

            //Act & Assert
            Assert.True(store.TryConsume(idA, maxRequests, window));
            Assert.False(store.TryConsume(idA, maxRequests, window));
            Assert.True(store.TryConsume(idB, maxRequests, window));
            Assert.False(store.TryConsume(idB, maxRequests, window));
        }
    }
}