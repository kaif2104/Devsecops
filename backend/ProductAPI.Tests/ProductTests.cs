using NUnit.Framework;
using ProductAPI.Models;

namespace ProductAPI.Tests
{
    [TestFixture]
    public class ProductTests
    {
        [Test]
        public void Product_Model_Initialization_Success()
        {
            var product = new Product
            {
                Id = 1,
                ProductName = "Test Laptop",
                Price = 999.99m
            };

            Assert.That(product.Id, Is.EqualTo(999));
            Assert.That(product.ProductName, Is.EqualTo("Test Laptop"));
            Assert.That(product.Price, Is.EqualTo(999.99m));
        }

        [Test]
        public void Product_Price_Must_Be_Positive()
        {
            var product = new Product { Price = 100.00m };
            Assert.That(product.Price, Is.GreaterThan(0));
        }
    }
}
