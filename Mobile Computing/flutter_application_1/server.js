// server.js

const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables from .env file
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json()); // To parse JSON bodies

// Test Route
app.get('/', (req, res) => {
  res.send('Backend Server is Running');
});

// Start Server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
