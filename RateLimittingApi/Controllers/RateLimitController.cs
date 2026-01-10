using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RateLimittingApi.ConfigModels;
using RateLimittingApi.Interfaces;
using RateLimittingApi.RequestModel;

namespace RateLimittingApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class RateLimitController : ControllerBase
    {
        private readonly IRateLimitService _rateLimitService;
        private readonly IOptionsMonitor<RateLimitOptions> _optionsMonitor;

        public RateLimitController(IRateLimitService service, IOptionsMonitor<RateLimitOptions> optionsMonitor)
        {
            _rateLimitService = service;
            _optionsMonitor = optionsMonitor;
        }


        /// <summary>
        /// Checks whether the specified request is allowed under the current rate limiting policy.
        /// </summary>
        /// <remarks>If the request exceeds the rate limit, the response includes a 'Retry-After' header
        /// specifying the number of seconds to wait before making another request. This endpoint is typically used to
        /// enforce client-side rate limiting policies.</remarks>
        /// <param name="request">The request containing the identifier to be checked for rate limit compliance. Cannot be null.</param>
        /// <param name="cancellationToken">A cancellation token that can be used to cancel the operation.</param>
        /// <returns>An HTTP 200 OK result if the request is allowed; otherwise, an HTTP 429 Too Many Requests result with a
        /// 'Retry-After' header indicating when the client may retry.</returns>
        [HttpPost]
        [Route("/check")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
        public async Task<IActionResult> Check([FromBody] CheckRequest request, CancellationToken cancellationToken)
        {
            if (request == null)
            {
                return BadRequest("Id is Required");
            }

            var allowed = await _rateLimitService.CheckAccessAsync(request.Id, cancellationToken);

            if (allowed)
                return Ok();

            var retrySeconds = _optionsMonitor.CurrentValue.TimeWindow;
            Response.Headers["Retry-After"] = retrySeconds.ToString();

            return StatusCode(429);
        }
    }
}
