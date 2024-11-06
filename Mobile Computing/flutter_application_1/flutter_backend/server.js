// server.js

const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');

// Load environment variables from .env file
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json()); // To parse JSON bodies

// Create a MySQL pool
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test Route
app.get('/', (req, res) => {
  res.send('Backend Server is Running');
});

// Get all trainings
app.get('/api/trainings', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, date, training_name FROM trainings');
    res.json(rows);
  } catch (error) {
    console.error('Error fetching trainings:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Add a new training
app.post('/api/trainings', async (req, res) => {
  const { date, training_name } = req.body;

  if (!date || !training_name) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const [result] = await pool.query(
      'INSERT INTO trainings (date, training_name) VALUES (?, ?)',
      [date, training_name]
    );
    res.status(201).json({ message: 'Training added', id: result.insertId });
  } catch (error) {
    console.error('Error adding training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Update a training by ID
app.put('/api/trainings/:id', async (req, res) => {
  const { id } = req.params;
  const { date, training_name } = req.body;

  try {
    const [result] = await pool.query(
      'UPDATE trainings SET date = ?, training_name = ? WHERE id = ?',
      [date, training_name, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Training not found' });
    }

    res.json({ message: 'Training updated' });
  } catch (error) {
    console.error('Error updating training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Delete a training by ID
app.delete('/api/trainings/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const [result] = await pool.query('DELETE FROM trainings WHERE id = ?', [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Training not found' });
    }

    res.json({ message: 'Training deleted' });
  } catch (error) {
    console.error('Error deleting training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Start Server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
