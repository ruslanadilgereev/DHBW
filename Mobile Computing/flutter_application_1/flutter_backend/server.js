// server.js

const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
const app = express();
const port = process.env.PORT || 3001;

// Load environment variables from .env file
dotenv.config();

// Definiere die CORS-Optionen
const corsOptions = {
  origin: 'http://localhost:3000', // Ersetze 8080 durch den Port, auf dem deine Flutter-App läuft
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

// Verwende die CORS-Middleware mit den Optionen
app.use(cors(corsOptions));

// Behandle Preflight-Anfragen
app.options('*', cors(corsOptions));

// Middleware
//app.use(express.json({ type: ['application/json', 'text/plain'] }));
app.use(express.json());


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
    const [trainings] = await pool.query(
      'SELECT t.id, t.training_name, ' +
      'GROUP_CONCAT(DISTINCT td.date ORDER BY td.date ASC) AS dates ' +
      'FROM trainings t ' +
      'LEFT JOIN training_dates td ON t.id = td.training_id ' +
      'GROUP BY t.id'
    );

    res.json(
      trainings.map((training) => ({
        ...training,
        dates: training.dates ? training.dates.split(',') : [],
      }))
    );
  } catch (error) {
    console.error('Error fetching trainings:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});


app.post('/api/trainings', async (req, res) => {
  const { training_name, dates } = req.body;

  if (!training_name || !Array.isArray(dates) || dates.length === 0) {
    return res.status(400).json({ error: 'Missing required fields or invalid format' });
  }

  try {
    // Training einfügen
    const [trainingResult] = await pool.query(
      'INSERT INTO trainings (training_name) VALUES (?)',
      [training_name]
    );
    const trainingId = trainingResult.insertId;

    // Termine einfügen
    const dateValues = dates.map((date) => [trainingId, date]);
    if (dateValues.length > 0) {
      await pool.query(
        'INSERT INTO training_dates (training_id, date) VALUES ?',
        [dateValues]
      );
    }

    res.status(201).json({ message: 'Training added successfully', id: trainingId });
  } catch (error) {
    console.error('Error adding training:', error);
    res.status(500).json({ error: 'Internal Server Error', details: error.message });
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
    // Clear references to the training in the bookings table
    await pool.query('UPDATE bookings SET training_id = NULL WHERE training_id = ?', [id]);

    // Delete the training
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



// Benutzer registrieren

app.post('/api/register', async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password || !role) {
    return res.status(400).json({ error: 'Alle Felder sind erforderlich' });
  }

  try {
    // Überprüfen, ob der Benutzer bereits existiert
    const [existingUser] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existingUser.length > 0) {
      return res.status(400).json({ error: 'Benutzer existiert bereits' });
    }

    // Passwort hashen
    const hashedPassword = await bcrypt.hash(password, 10);

    // Benutzer erstellen
    await pool.query(
      'INSERT INTO users (email, password, role) VALUES (?, ?, ?)',
      [email, hashedPassword, role]
    );
    res.status(201).json({ message: 'Benutzer registriert' });
  } catch (error) {
    console.error('Fehler bei der Registrierung:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});


// Benutzer anmelden
// server.js (zusätzlicher Endpunkt für Login)

const bcrypt = require('bcryptjs'); // Für Passwort-Hashing (sollte installiert sein)

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'E-Mail und Passwort sind erforderlich' });
  }

  try {
    // Benutzer aus der Datenbank abrufen
    const [rows] = await pool.query('SELECT id, email, password, role FROM users WHERE email = ?', [email]);

    if (rows.length === 0) {
      // Benutzer existiert nicht
      return res.status(401).json({ error: 'Ungültige Anmeldeinformationen' });
    }

    const user = rows[0];

    // Passwortüberprüfung mit bcrypt
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Ungültige Anmeldeinformationen' });
    }

    // Anmeldung erfolgreich
    res.json({
      message: 'Anmeldung erfolgreich',
      role: user.role,
      userId: user.id,
    });
  } catch (error) {
    console.error('Fehler bei der Anmeldung:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});


// Create a booking
app.post('/api/bookings', async (req, res) => {
  const { user_id, training_id } = req.body;

  if (!user_id || !training_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // Überprüfung auf bestehende Buchung
    const [existingBooking] = await pool.query(
      'SELECT id FROM bookings WHERE user_id = ? AND training_id = ?',
      [user_id, training_id]
    );

    if (existingBooking.length > 0) {
      return res.status(400).json({ error: 'You have already booked this training' });
    }

    // Buchung erstellen
    await pool.query(
      'INSERT INTO bookings (user_id, training_id) VALUES (?, ?)',
      [user_id, training_id]
    );

    res.status(201).json({ message: 'Training booked successfully' });
  } catch (error) {
    console.error('Error booking training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});



// Get bookings for a specific training
app.get('/api/trainings/:id/bookings', async (req, res) => {
  const { id } = req.params;
  try {
    const [rows] = await pool.query(
      `SELECT bookings.id, users.email AS user_email
      FROM bookings
      JOIN users ON bookings.user_id = users.id
      WHERE bookings.training_id = ?`,
      [id]
    );
    res.json(rows);
  } catch (error) {
    console.error('Error fetching bookings:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});


app.get('/api/trainings', async (req, res) => {
  try {
    const [trainings] = await pool.query(
      'SELECT t.id, t.training_name, GROUP_CONCAT(td.date ORDER BY td.date ASC) AS dates ' +
      'FROM trainings t ' +
      'LEFT JOIN training_dates td ON t.id = td.training_id ' +
      'GROUP BY t.id'
    );

    res.json(trainings.map((training) => ({
      ...training,
      dates: training.dates ? training.dates.split(',') : [],
    })));
  } catch (error) {
    console.error('Error fetching trainings:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});


app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});