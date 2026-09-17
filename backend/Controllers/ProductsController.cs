using Microsoft.AspNetCore.Mvc;
using Npgsql;
using ProductAPI.Models;

namespace ProductAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public ProductsController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpGet]
        public IActionResult GetProducts()
        {
            var products = new List<Product>();

            string connString =
                _configuration.GetConnectionString("DefaultConnection") ?? "";

            using (var conn = new NpgsqlConnection(connString))
            {
                conn.Open();

                using (var cmd = new NpgsqlCommand("SELECT id, productname, price FROM products ORDER BY id ASC", conn))
                {
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            products.Add(new Product
                            {
                                Id = reader.GetInt32(0),
                                ProductName = reader.GetString(1),
                                Price = reader.GetDecimal(2)
                            });
                        }
                    }
                }
            }

            return Ok(products);
        }

        [HttpPost]
        public IActionResult AddProduct([FromBody] Product product)
        {
            if (product == null || string.IsNullOrWhiteSpace(product.ProductName))
            {
                return BadRequest("Invalid product data");
            }

            string connString =
                _configuration.GetConnectionString("DefaultConnection") ?? "";

            using (var conn = new NpgsqlConnection(connString))
            {
                conn.Open();

                using (var cmd = new NpgsqlCommand("INSERT INTO products (productname, price) VALUES (@name, @price) RETURNING id", conn))
                {
                    cmd.Parameters.AddWithValue("@name", product.ProductName);
                    cmd.Parameters.AddWithValue("@price", product.Price);

                    var newId = cmd.ExecuteScalar();
                    product.Id = Convert.ToInt32(newId);
                }
            }

            return Ok(new { message = "Product Saved Successfully", product });
        }
    }
}