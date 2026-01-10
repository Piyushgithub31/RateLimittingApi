using RateLimittingApi.ConfigModels;
using RateLimittingApi.Interfaces;
using RateLimittingApi.Service;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.Configure<RateLimitOptions>(builder.Configuration.GetSection("RateLimiting"));

builder.Services.AddSingleton<IInMemoryRateLimitStore, InMemoryFixedWindowRateLimitStore>();
builder.Services.AddSingleton<IRateLimitService, RateLimitService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
