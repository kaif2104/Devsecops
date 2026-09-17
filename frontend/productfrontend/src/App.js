import React, { useEffect, useState } from "react";
import axios from "axios";

function App() {
  const [products, setProducts] = useState([]);
  const [productName, setProductName] = useState("");
  const [price, setPrice] = useState("");
  const [statusMsg, setStatusMsg] = useState("");

  // Use relative URL so Nginx reverse proxy routes to /api/products,
  // or fallback to REACT_APP_API_URL environment variable if provided.
  const API_URL = process.env.REACT_APP_API_URL || "/api/products";

  const loadProducts = async () => {
    try {
      const response = await axios.get(API_URL);
      setProducts(response.data || []);
      setStatusMsg("");
    } catch (err) {
      console.error("Failed to load products:", err);
      setStatusMsg("Error connecting to backend API: " + err.message);
    }
  };

  useEffect(() => {
    loadProducts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const addProduct = async (e) => {
    if (e) e.preventDefault();
    if (!productName || !price) {
      alert("Please enter both product name and price");
      return;
    }

    try {
      await axios.post(API_URL, {
        productName,
        price: Number(price)
      });

      setProductName("");
      setPrice("");
      loadProducts();
    } catch (err) {
      console.error("Failed to add product:", err);
      alert("Error adding product: " + err.message);
    }
  };

  return (
    <div style={{ padding: "30px", fontFamily: "Segoe UI, sans-serif", maxWidth: "600px", margin: "0 auto" }}>
      <h2>Product Management</h2>

      {statusMsg && (
        <div style={{ color: "red", marginBottom: "15px", padding: "10px", backgroundColor: "#fee", borderRadius: "4px" }}>
          {statusMsg}
        </div>
      )}

      <form onSubmit={addProduct}>
        <div style={{ marginBottom: "10px" }}>
          <input
            style={{ width: "100%", padding: "8px", boxSizing: "border-box" }}
            placeholder="Product Name"
            value={productName}
            onChange={(e) => setProductName(e.target.value)}
          />
        </div>

        <div style={{ marginBottom: "10px" }}>
          <input
            style={{ width: "100%", padding: "8px", boxSizing: "border-box" }}
            type="number"
            step="0.01"
            placeholder="Price"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
          />
        </div>

        <button
          type="submit"
          style={{ padding: "8px 16px", backgroundColor: "#007bff", color: "white", border: "none", borderRadius: "4px", cursor: "pointer" }}
        >
          Add Product
        </button>
      </form>

      <hr style={{ margin: "25px 0" }} />

      <h3>Products List</h3>
      {products.length === 0 ? (
        <p style={{ color: "#666" }}>No products found or loading...</p>
      ) : (
        <ul style={{ listStyleType: "none", padding: 0 }}>
          {products.map((p, idx) => (
            <li
              key={p.id || p.Id || idx}
              style={{ padding: "10px", borderBottom: "1px solid #ddd", display: "flex", justifyContent: "space-between" }}
            >
              <strong>{p.productName || p.ProductName || p.name}</strong>
              <span>₹{p.price || p.Price}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default App;
