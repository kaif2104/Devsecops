using Npgsql;

var builder = WebApplication.CreateBuilder(args);


// Controllers
builder.Services.AddControllers();

// CORS policy
builder.Services.AddCors(options =>
{
    options.AddPolicy("ReactPolicy",
        policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
});

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Enable Swagger in all environments for testing
app.UseSwagger();
app.UseSwaggerUI();

// Enable CORS
app.UseCors("ReactPolicy");

// Health check endpoint (verifies DB connection)
app.MapGet("/health", async (IConfiguration config) =>
{
    try
    {
        string connString = config.GetConnectionString("DefaultConnection") ?? "";
        await using var conn = new NpgsqlConnection(connString);
        await conn.OpenAsync();
        return Results.Ok(new { status = "Healthy", database = "Connected", timestamp = DateTime.UtcNow });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Database connection failed: {ex.Message}", statusCode: 503);
    }
});

// Controllers
app.MapControllers();

app.Run();